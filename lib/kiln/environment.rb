# frozen_string_literal: true

module Kiln
  Environment = Data.define(:name) do
    def self.current = new(name: ENV.fetch("KILN_ENV", "development"))

    def initialize(name:)
      unless %w[development test production].include?(name)
        raise Error, "KILN_ENV must be development, test, or production (got #{name.inspect})"
      end

      super
    end

    def development? = name == "development"
    def test? = name == "test"
    def production? = name == "production"
  end
end
