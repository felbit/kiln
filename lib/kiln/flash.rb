# frozen_string_literal: true

module Kiln
  # Redirect messages
  class Flash
    KEY = "_flash"

    def initialize(session)
      @session = session
      @current = session.delete(KEY) || {}
      @next = {}
    end

    def [](key) = @current[key.to_s]

    def []=(key, value)
      @next[key.to_s] = value
      @session[KEY] = @next
    end
  end
end
