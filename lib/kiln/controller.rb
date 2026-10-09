# frozen_string_literal: true

module Kiln
  # Base class for application controllers
  class Controller
    class DoubleRenderError < Kiln::Error; end

    FRAMEWORK_IVARS = %i[@env @params @runtime @response].freeze

    attr_reader :env, :params

    def initialize(env, params, runtime)
      @env = env
      @params = params
      @runtime = runtime
      @response = nil
    end

    def render(template = nil, plain: nil, html: nil, status: 200, layout: "application")
      html = views.render(template_name(template), assigns, layout:) if template

      if html
        commit(status, { "content-type" => "text/html; charset=utf-8" }, [html])
      else
        commit(status, { "content-type" => "text/plain; charset=utf-8" }, [plain.to_s])
      end
    end

    def redirect_to(location, status: 303)
      commit(status, { "location" => location }, [])
    end

    def head(status)
      commit(status, {}, [])
    end

    def process(action)
      public_send(action)
      default = "#{controller_name}/#{action}"
      render(default) if @response.nil? && @runtime.views&.template?(default)
      @response || [204, {}, []]
    end

    def db
      database = @runtime.database or
        raise Error, "no database configured; add `database url: ...` to your application"

      database.connection
    end

    def controller_name
      self.class.name.delete_suffix("Controller").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
    end

    def nested_params(key)
      value = params[key]
      value.is_a?(Hash) ? value : {}
    end

    private

    def commit(status, headers, body)
      raise DoubleRenderError, "#{self.class} tried to respond twice in one request" if @response

      @response = [status, headers, body]
    end

    def views
      @runtime.views or raise Error, "no views configured; add `views \"app/views\"` to your application"
    end

    def template_name(template)
      template.is_a?(Symbol) ? "#{controller_name}/#{template}" : template
    end

    def assigns
      (instance_variables - FRAMEWORK_IVARS).to_h { [it, instance_variable_get(it)] }
    end
  end
end
