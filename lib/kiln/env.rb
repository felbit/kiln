# frozen_string_literal: true

module Kiln
  # Loads KEY=VALUE pairs from a .env file into ENV.
  module Env
    LINE = /\A\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/
    QUOTES = %w[" '].freeze

    def self.load(path)
      return unless File.file?(path)

      File.foreach(path).with_index(1) do |line, number|
        next if line.strip.empty? || line.lstrip.start_with?("#")

        match = LINE.match(line.chomp) or raise Error, "#{path}:#{number}: expected KEY=VALUE"
        ENV[match[1]] ||= unquote(match[2].strip)
      end
    end

    def self.unquote(value)
      quoted = value.length >= 2 && QUOTES.include?(value[0]) && value[0] == value[-1]
      quoted ? value[1..-2] : value
    end

    private_class_method :unquote
  end
end
