# frozen_string_literal: true

require "pg"
require_relative "database/connection"

module Kiln
  # Database configuration and per-thread connection management.
  class Database
    KEY = :kiln_db_connection

    attr_reader :url

    def initialize(url:)
      @url = url
    end

    def connection
      conn = Thread.current.thread_variable_get(KEY)
      unless conn
        conn = Connection.new(PG.connect(@url))
        Thread.current.thread_variable_set(KEY, conn)
      end
      conn.ensure_alive!
      conn
    end

    def clean_up_after_request
      Thread.current.thread_variable_get(KEY)&.clean_up!
    rescue PG::Error
      nil
    end

    def disconnect
      Thread.current.thread_variable_get(KEY)&.close
      Thread.current.thread_variable_set(KEY, nil)
    end

    def verify!
      PG.connect(@url).close
    rescue PG::Error => e
      raise Error, "can't connect to the database: #{e.message.strip}"
    end
  end
end
