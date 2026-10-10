# frozen_string_literal: true

require "pg"

module Kiln
  # Database administration commands for the CLI
  module DatabaseTasks
    def self.create(url, out: $stdout)
      options = connection_options(url)
      name = options.delete(:dbname) or raise Error, "the database URL names no database"

      conn = PG.connect(**options, dbname: "postgres")
      conn.exec("CREATE DATABASE #{conn.quote_ident(name)}")
      out.puts "Created database #{name}"
    rescue PG::DuplicateDatabase
      out.puts "Database #{name} already exists"
    rescue PG::InsufficientPrivilege
      raise Error, "the database user may not create databases; grant it with: ALTER ROLE <user> CREATEDB"
    rescue PG::ConnectionBad => e
      raise Error, "can't connect to the database server: #{e.message.strip}"
    ensure
      conn&.close
    end

    def self.connection_options(url)
      PG::Connection.conninfo_parse(url).each_with_object({}) do |option, options|
        options[option[:keyword].to_sym] = option[:val] if option[:val]
      end
    end
  end
end
