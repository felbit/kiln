# frozen_string_literal: true

require "rack/query_parser"

module Kiln
  module Params

    PARSER = Ractor.make_shareable(Rack::QueryParser.make_default(32))
    MAX_FORM_BYTES = 1024*1024
    FORM_TYPE = "application/x-www-form-urlencoded"
    OVERRIDABLE_VERBS = %w[PATCH PUT DELETE].freeze

    # Malformed parameters error code
    class Error < Kiln::Error
      def status = 400
    end

    # Body exceeds MAX_FORM_BYTES
    class TooLarge < Error
      def status = 413
    end

    def self.parse(env)
      params = PARSER.parse_nested_query(env["QUERY_STRING"])
      params.merge!(PARSER.parse_nested_query(read_form(env))) if form?(env)
      check_encoding!(params)
      params
    rescue Rack::BadRequest => e
      raise Error, "invalid parameters: #{e.message}"
    end

    def self.verb(env, params)
      verb = env["REQUEST_METHOD"]
      override = params["_method"].to_s.upcase
      return verb unless verb == "POST" && OVERRIDABLE_VERBS.include?(override)

      env["kiln.original_method"] = verb
      env["REQUEST_METHOD"] = override
    end

    def self.form?(env)
      env["CONTENT_TYPE"].to_s.split(";").first.to_s.strip.downcase == FORM_TYPE
    end

    def self.read_form(env)
      input = env["rack.input"] or return ""
      raise TooLarge, "form body too large" if env["CONTENT_LENGTH"].to_i > MAX_FORM_BYTES

      body = input.read(MAX_FORM_BYTES + 1).to_s
      raise TooLarge, "form body too large" if body.bytesize > MAX_FORM_BYTES

      body
    end

    def self.check_encoding!(value)
      case value
      when Hash
        value.each do |key, item|
          check_encoding!(key)
          check_encoding!(item)
        end
      when Array then value.each { check_encoding!(it) }
      when String then raise Error, "parameters must be valid UTF-8" unless value.valid_encoding?
      end
    end

    private_class_method :form?, :read_form, :check_encoding!
  end
end
