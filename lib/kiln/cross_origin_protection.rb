# frozen_string-literal: true

module Kiln
  # Stateless, header-based, cross-origin protection
  #
  # Uses Sec-Fetch-Site when present, falls back to Origin
  class CrossOriginProtection
    SAFE_METHODS = %w[GET HEAD OPTIONS].freeze
    SAFE_FETCH_SITES = %w[same-origin none].freeze
    SCHEME = %r{\A[a-z][a-z0-9+.-]*://}i

    def initialize(trusted_origins: [])
      @trusted_origins = trusted_origins.map { normalize(it) }
    end

    def allowed?(env)
      return true if SAFE_METHODS.include?(env["REQUEST_METHOD"])

      origin = env["HTTP_ORIGIN"]
      case env["HTTP_SEC_FETCH_SITE"]
      when nil, ""
        # older browser or non-browser client: fallback to Origin
      when *SAFE_FETCH_SITES then return true
      else return trusted?(origin)
      end

      return true if origin.nil? || origin.empty?

      same_host?(origin, env["HTTP_HOST"]) || trusted?(origin)
    end

    private

    def same_host?(origin, host)
      return false if host.nil? || origin == "null"

      origin.sub(SCHEME, "").casecmp?(host)
    end

    def trusted?(origin) = !origin.nil? && @trusted_origins.include?(normalize(origin))

    def normalize(origin) = origin.to_s.downcase.chomp("/")
  end
end
