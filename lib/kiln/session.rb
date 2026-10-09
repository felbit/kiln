# frozen_string_literal: true

module Kiln
  class Session
    def initialize(store, cookie_value)
      @store = store
      @cookie_value = cookie_value
      @data = nil
      @changed = false
    end

    def [](key) = data[key.to_s]

    def []=(key, value)
      data[key.to_s] = value
      @changed = true
    end

    def delete(key)
      return unless data.key?(key.to_s)

      @changed = true
      data.delete(key.to_s)
    end

    def clear
      @data = {}
      @changed = true
    end

    def changed? = @changed

    def to_h = data.dup

    private

    def data = @data ||= (@store.decode(@cookie_value) || {})
  end
end
