# frozen_string_literal: true

require "pg"
require "zlib"
require_relative "migration"

module Kiln
  # Finds, applies and reverts migrations in db/migrate.
  class Migrator
    FILE_PATTERN = /\A(\d{14})_([a-z0-9_]+)\.rb\z/
    LOCK_KEY = Zlib.crc32("kiln:migrations")

    MigrationFile = Data.define(:version, :name, :path) do
      def class_name = name.split("_").map(&:capitalize).join
    end

    def initialize(url:, path: "db/migrate", out: $stdout)
      @url = url
      @path = path
      @out = out
    end

    def migrate
      with_connection do |conn|
        applied = applied_versions(conn)
        pending = files.reject { applied.include?(it.version) }
        @out.puts "Nothing to migrate." if pending.empty?
        pending.each { run(conn, it, :up) }
      end
    end

    def rollback(steps: 1)
      with_connection do |conn|
        applied = applied_versions(conn)
        targets = files.select { applied.include?(it.version) }.last(steps).reverse
        @out.puts "Nothing to roll back." if targets.empty?
        targets.each { run(conn, it, :down) }
      end
    end

    # @return [Array<Array(String, String, String)>] [state, version, name] rows
    def status
      with_connection do |conn|
        applied = applied_versions(conn)
        known = files
        rows = known.map { [applied.include?(it.version) ? "up" : "down", it.version, it.name] }
        orphans = (applied - known.map(&:version)).map { ["up", it, "** NO FILE **"] }
        (rows + orphans).sort_by { it[1] }
      end
    end

    private

    def with_connection
      conn = PG.connect(@url)
      conn.exec_params("SELECT pg_advisory_lock($1)", [LOCK_KEY])
      unless conn.exec("SELECT to_regclass('schema_migrations') AS t").first["t"]
        conn.exec(<<~SQL)
          CREATE TABLE schema_migrations (
            version    text PRIMARY KEY,
            applied_at timestamptz NOT NULL DEFAULT now()
          )
        SQL
      end
      yield conn
    rescue PG::ConnectionBad => e
      raise Error, "can't connect to the database: #{e.message.strip}"
    ensure
      conn&.close
    end

    def applied_versions(conn)
      conn.exec("SELECT version FROM schema_migrations").column_values(0).to_set
    end

    def files
      return [] unless Dir.exist?(@path)

      list = Dir.children(@path).sort.filter_map do |entry|
        m = FILE_PATTERN.match(entry) or next
        MigrationFile.new(version: m[1], name: m[2], path: File.join(@path, entry))
      end

      duplicates = list.group_by(&:version).select { |_, group| group.size > 1 }.keys
      raise Error, "duplicate migration versions: #{duplicates.join(", ")}" if duplicates.any?

      list
    end

    def run(conn, file, direction)
      migration = load_migration(file).new(conn)
      @out.puts "== #{file.version} #{file.class_name}: #{direction == :up ? "migrating" : "reverting"}"

      apply = lambda do
        migration.public_send(direction)
        if direction == :up
          conn.exec_params("INSERT INTO schema_migrations (version) VALUES ($1)", [file.version])
        else
          conn.exec_params("DELETE FROM schema_migrations WHERE version = $1", [file.version])
        end
      end

      migration.transaction? ? conn.transaction { apply.call } : apply.call
    end

    def load_migration(file)
      require File.expand_path(file.path)
      klass = Object.const_get(file.class_name) if Object.const_defined?(file.class_name)
      return klass if klass.is_a?(Class) && klass < Migration

      raise Error, "#{file.path} must define #{file.class_name} < Kiln::Migration"
    end
  end
end
