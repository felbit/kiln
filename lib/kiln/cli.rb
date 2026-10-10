# frozen_string_literal: true

require "fileutils"
require "securerandom"
require_relative "migrator"
require_relative "generators/app"

module Kiln
  # The `kiln` command-line tool
  module CLI
    USAGE = <<~TEXT
      Usage:
        kiln new PATH                    Create a new Kiln app
          [--kiln-path=DIR] [--skip-bundle]
        kiln db:migrate                  Apply pending migrations
        kiln db:rollback [STEPS]         Revert the last STEPS migrations (default 1)
        kiln db:status                   Show which migrations have run
        kiln generate migration NAME     Create db/migrate/TIMESTAMP_NAME.rb
        kiln secret                      Generate a random secret for KILN_SECRET_KEY
    TEXT

    def self.start(argv)
      case argv
      in ["new", path, *flags]             then new_app(path, flags)
      in ["db:migrate"]                    then migrator.migrate
      in ["db:rollback"]                   then migrator.rollback
      in ["db:rollback", steps]            then migrator.rollback(steps: Integer(steps))
      in ["db:status"]                     then print_status(migrator.status)
      in ["generate", "migration", name]   then generate_migration(name)
      in ["secret"]                        then puts SecureRandom.hex(64)
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

    def self.new_app(path, flags)
      kiln_path = nil
      bundle = true

      flags.each do |flag|
        if flag.start_with?("--kiln-path=") then kiln_path = flag.delete_prefix("--kiln-path=")
        elsif flag == "--skip-bundle" then bundle = false
        else raise Error, "unknown option #{flag}"
        end
      end

      Generators::App.new(path, kiln_path:).run(bundle:)
    end
  end
end
