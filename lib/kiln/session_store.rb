# frozen_string_literal: true

require "openssl"
require "json"

module Kiln
  class SessionStore
    MIN_SECRET_BYTES = 32
    MAX_COOKIE_BYTES = 4000
    IV_BYTES = 12
    TAG_BYTES = 16
    MAX_AGE = 30 * 24 * 60 * 60
    COOKIE_NAME = "_kiln_session"

    def initialize(secret:, cookie_name: COOKIE_NAME, max_age: MAX_AGE)
      if secret.to_s.bytesize < MIN_SECRET_BYTES
        raise Error, "session secret must be at least #{MIN_SECRET_BYTES} bytes; generate one with `kiln secret`"
      end

      @key = OpenSSL::KDF.hkdf(secret, salt: "kiln session", info: "aes-256-gcm", length: 32, hash: "SHA256")
      @cookie_name = cookie_name
      @max_age = max_age
    end

    def read_cookie(env)
      env["HTTP_COOKIE"].to_s.split(/;\s*/).each do |pair|
        name, value = pair.split("=", 2)
        return value if name == @cookie_name
      end
      nil
    end

    def decode(value)
      return nil if value.nil? || value.empty?

      raw = value.unpack1("m0")
      return nil if raw.bytesize < IV_BYTES + TAG_BYTES

      cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
      cipher.key = @key
      cipher.iv = raw.byteslice(0, IV_BYTES)
      cipher.auth_tag = raw.byteslice(IV_BYTES, TAG_BYTES)
      cipher.auth_data = @cookie_name
      json = cipher.update(raw.byteslice(IV_BYTES + TAG_BYTES..)) + cipher.final

      payload = JSON.parse(json)
      return nil unless payload.is_a?(Hash) && payload["exp"].to_i > Time.now.to_i

      payload["data"].is_a?(Hash) ? payload["data"] : nil
    rescue ArgumentError, OpenSSL::Cipher::CipherError, JSON::ParserError
      nil
    end

    def encode(data)
      payload = JSON.generate({ "data" => data, "exp" => Time.now.to_i + @max_age })

      cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
      cipher.key = @key
      iv = cipher.random_iv
      cipher.auth_data = @cookie_name
      ciphertext = cipher.update(payload) + cipher.final

      [iv + cipher.auth_tag + ciphertext].pack("m0")
    end

    def cookie(data, env)
      value = encode(data)
      if value.bytesize > MAX_COOKIE_BYTES
        raise Error, "session too large (#{value.bytesize} bytes); keep only small values like IDs in it"
      end

      parts = ["#{@cookie_name}=#{value}", "path=/", "max-age=#{@max_age}", "httponly", "samesite=lax"]
      parts << "secure" if env["rack.url_scheme"] == "https"
      parts.join("; ")
    end
  end
end
