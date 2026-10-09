# frozen_string_literal: true

require "uri"

module Kiln
  class Static
    CONTENT_TYPES = {
      ".html" => "text/html; charset=utf-8",
      ".css" => "text/css; charset=utf-8",
      ".js" => "text/javascript; charset=utf-8",
      ".txt" => "text/plain; charset=utf-8",
      ".svg" => "image/svg+xml",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".ico" => "image/x-icon",
      ".woff2" => "font/woff2"
    }.freeze
    DEFAULT_TYPE = "application/octet-stream"
    METHODS = %w[GET HEAD].freeze

    class FileBody
      CHUNK_BYTES = 16 * 1024

      def initialize(path)
        @path = path
      end

      def each
        return enum_for(:each) unless block_given?

        File.open(@path, "rb") do |file|
          while (chunk = file.read(CHUNK_BYTES))
            yield chunk
          end
        end
      end

      def to_path = @path
    end

    def initialize(root)
      raise Error, "static files directory #{root} does not exist" unless Dir.exist?(root)

      real_root = File.realpath(root)
      @files = Dir.glob("**/*", base: real_root).each_with_object({}) do |relative, files|
        path = File.join(real_root, relative)
        next unless File.file?(path)
        next unless File.realpath(path).start_with?("#{real_root}/")

        files["/#{relative}"] = path
      end
    end

    def call(env)
      return unless METHODS.include?(env["REQUEST_METHOD"])

      path = @files[decode(env["PATH_INFO"])] or return
      stat = File.stat(path)
      etag = %("#{stat.mtime.to_i.to_s(16)}-#{stat.size.to_s(16)}")
      headers = { "etag" => etag, "cache-control" => "no-cache" }
      return [304, headers, []] if env["HTTP_IF_NONE_MATCH"] == etag

      headers["content-type"] = CONTENT_TYPES.fetch(File.extname(path).downcase, DEFAULT_TYPE)
      headers["content-length"] = stat.size.to_s
      headers["x-content-type-options"] = "nosniff"
      [200, headers, env["REQUEST_METHOD"] == "HEAD" ? [] : FileBody.new(path)]
    rescue Errno::ENOENT
      nil
    end

    private

    def decode(path)
      decoded = URI.decode_uri_component(path.to_s)
      decoded.valid_encoding? ? decoded : nil
    end
  end
end
