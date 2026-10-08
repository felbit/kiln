# frozen_string_literal: true

require "erubi"

module Kiln
  # Ractor-safe Erubi template compilation
  module View
    class SafeString < String; end

    ESCAPES = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;", "'" => "&#39;" }.freeze
    ESCAPE_PATTERN = /[&<>"']/

    def self.escape(value)
      return value if value.is_a?(SafeString)

      value.to_s.gsub(ESCAPE_PATTERN, ESCAPES)
    end

    class Context
      def initialize(assigns)
        assigns.each { |name, value| instance_variable_set(name, value) }
      end

      def raw(value) = SafeString.new(value.to_s)
    end

    class Library
      def initialize(context_class, templates)
        @context_class = context_class
        @templates = templates
      end

      def template?(name) = @templates.key?(name)

      def render(name, assigns, layout: "application")
        method_name = @templates.fetch(name) { raise Error, "no template named #{name.inspect}" }
        context = @context_class.new(assigns)
        body = SafeString.new(context.public_send(method_name))
        return body unless layout

        layout_method = @templates["layouts/#{layout}"]
        if layout_method.nil?
          return body if layout == "application"

          raise Error, "no layout named #{layout.inspect}"
        end

        SafeString.new(context.public_send(layout_method) { body })
      end
    end

    def self.compile(root)
      raise Error, "views directory #{root} does not exist" unless Dir.exist?(root)

      templates_module = Module.new
      templates = {}

      Dir.glob("**/*.html.erb", base: root).sort.each_with_index do |relative, index|
        path = File.join(root, relative)
        method_name = :"_kiln_template_#{index}"
        source = Erubi::Engine.new(
          File.read(path), escape: true, escapefunc: "::Kiln::View.escape"
        ).src

        templates_module.module_eval("def #{method_name}; #{source}\nend", path, 1)
        templates[relative.delete_suffix(".html.erb")] = method_name
      end

      Library.new(Class.new(Context) { include templates_module }, templates)
    end
  end
end
