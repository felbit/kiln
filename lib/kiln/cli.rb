# frozen_string_literal: true

require "fileutils"
require_relative "migrator"

module Kiln
  # The `kiln` command-line tool
  module CLI
    USAGE = <<~TEXT
      Usage:
        kiln db:migrate                  apply pending migrations
        kiln db:rollback [STEPS]         revert the last STEPS migrations (default 1)
        kiln db:status                   show which migrations have run
        kiln generate migration NAME     create db/migrate/TIMESTAMP_NAME.rb
    TEXT

    def self.start(argv)
      case argv
      in ["db:migrate"]                    then migrator.migrate
      in ["db:rollback"]                   then migrator.rollback
      in ["db:rollback", steps]            then migrator.rollback(steps: Integer(steps))
      in ["db:status"]                     then print_status(migrator.status)
      in ["generate", "migration", name]   then generate_migration(name)
      else abort USAGE
      end
    rescue Kiln::Error, ArgumentError => e
      abort "kiln: #{e.message}"
    end

    def self.migrator
      url = ENV.fetch("DATABASE_URL") { abort "kiln: set DATABASE_URL to run database commands" }
      Migrator.new(url:)
    end

    def self.print_status(rows)
      puts "Status  Migration ID    Name", "-" * 50
      rows.each { |state, version, name| puts format("%-7s %-15s %s", state, version, name) }
    end

    def self.generate_migration(name)
      raise ArgumentError, "migration names must be snake_case, like create_posts" unless name.match?(/\A[a-z][a-z0-9_]*\z/)

      path = File.join("db/migrate", "#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_#{name}.rb")
      class_name = name.split("_").map(&:capitalize).join
      FileUtils.mkdir_p("db/migrate")
      File.write(path, <<~RUBY)
        class #{class_name} < Kiln::Migration
          def up
            execute <<~SQL
            SQL
          end

          def down
            execute <<~SQL
            SQL
          end
        end
      RUBY
      puts "created #{path}"
    end
  end
end
