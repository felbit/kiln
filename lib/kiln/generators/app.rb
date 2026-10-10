# frozen_string_literal: true

require "erubi"
require "fileutils"
require "securerandom"

module Kiln
  module Generators
    # Creates a new Kiln app from the templates in lib/kiln/templates/app
    class App
      TEMPLATES = File.expand_path("../templates/app", __dir__)
      NAME = /\A[a-z][a-z0-9_]*\z/

      def initialize(path, kiln_path: nil, out: $stdout)
        @name = File.basename(path)
        raise Error, "app names must be snake_case, like my_blog (got #{@name.inspect})" unless @name.match?(NAME)

        @module_name = @name.split("_").map(&:capitalize).join
        raise Error, "#{@module_name} is already a Ruby constant; choose another app name" if Object.const_defined?(@module_name)

        @target = File.expand_path(path)
        raise Error, "#{@target} already exists" if File.exist?(@target)

        @kiln_path = kiln_path && File.expand_path(kiln_path)
        @secret = SecureRandom.hex(64)
        @out = out
      end

      def run(bundle: true)
        Dir.glob("**/*", base: TEMPLATES).sort.each do |relative|
          source = File.join(TEMPLATES, relative)
          next if File.directory?(source)

          write(relative, source)
        end
        bundle_install if bundle
        @out.puts "", "Created #{@name}. Next:", "  cd #{@name}", "  createdb #{@name}_development"
      end

      def write(relative, source)
        path = target_path(relative)
        destination = File.join(@target, path)
        FileUtils.mkdir_p(File.dirname(destination))

        content = File.read(source)
        content = render(content, source) if relative.end_with?(".tt")
        File.write(destination, content)
        File.chmod(0o600, destination) if path == ".env"

        @out.puts "  create  #{path}"
      end

      def target_path(relative)
        relative.delete_suffix(".tt").split("/").map { it.sub(/\Adot_/, ".") }.join("/")
      end

      def render(content, source)
        eval(Erubi::Engine.new(content).src, binding, source) # rubocop:disable Security/Eval
      end

      def bundle_install
        @out.puts "  run     bundle install"
        install = -> { system("bundle", "install", chdir: @target) }
        ok = defined?(Bundler) ? Bundler.with_unbundled_env(&install) : install.call
        @out.puts "  bundle install failed; run it yourself inside #{@name}" unless ok
      end
    end
  end
end
