# frozen_string_literal: true

require "stringio"

module Kiln
  # An interactive session with a loaded and fired app
  class Console
    attr_reader :app, :db

    def initialize(application)
      @app = application.fire
      @db = application.database_url && Database.new(url: application.database_url).connection
    end

    def get(path) = request("GET", path)

    def start
      require "irb"
      binding.irb(show_code: false)
    end

    private

    def request(verb, path)
      path, query = path.split("?", 2)
      env = {
        "REQUEST_METHOD" => verb, "PATH_INFO" => path, "QUERY_STRING" => query.to_s,
        "HTTP_HOST" => "localhost", "rack.url_scheme" => "http", "rack.input" => StringIO.new
      }
      status, headers, body = app.call(env)
      [status, headers, body.each.to_a.join]
    end
  end
end
