# frozen_string_literal: true

module Kiln
  # Takes a configuration and calls #fire to create a deep-frozen,
  # Ractor-shareable Rack application
  class Application
    def initialize(&block)
      @router = Router.new
      @database = nil
      @views_path = nil
      @trusted_origins = []
      @session_options = nil
      @static_root = nil
      instance_eval(&block) if block
    end

    def routes(&) = @router.draw(&)

    def database(url:)
      @database = Database.new(url:)
    end

    def views(path)
      @views_path = path
    end

    def trusted_origins(*origins)
      @trusted_origins = origins
    end

    def session(secret:, **options)
      @session_options = { secret:, **options }
    end

    def static_files(path)
      @static_root = path
    end

    def fire
      @database&.verify!
      runtime = Runtime.new(
        database: @database,
        views: @views_path && View.compile(@views_path),
        cross_origin_protection: CrossOriginProtection.new(trusted_origins: @trusted_origins),
        sessions: @session_options && SessionStore.new(**@session_options),
        static: @static_root && Static.new(@static_root)
      )
      Ractor.make_shareable(Dispatcher.new(@router, resolve_controllers, runtime))
    end

    private

    def resolve_controllers
      @router.routes.each_with_object({}) do |route, controllers|
        klass = controllers[route.controller] ||= controller_class(route.controller)
        check_action!(klass, route)
      end
    end

    def controller_class(name)
      class_name = "#{name.split("_").map(&:capitalize).join}Controller"
      unless Object.const_defined?(class_name)
        raise Error, "routes point to \"#{name}\", but #{class_name} is not defined"
      end

      klass = Object.const_get(class_name)
      raise Error, "#{class_name} must inherit from Kiln::Controller" unless klass < Controller

      check_class_state!(klass)
      klass
    end

    def check_action!(klass, route)
      return if klass.public_method_defined?(route.action) &&
                !Controller.public_method_defined?(route.action)

      raise Error, "#{route.verb} #{route.path} points to #{klass}##{route.action}, which is not a public action"
    end

    def check_class_state!(klass)
      klass.ancestors.take_while { it != Controller }.each do |mod|
        mod.instance_variables.each do |ivar|
          value = mod.instance_variable_get(ivar)
          next if Ractor.shareable?(value)

          raise Error, "#{mod} holds class-level state in #{ivar} (#{value.class}); worker Ractors can't read it. Keep state in the database or per request."
        end
      end
      return if klass.class_variables.empty?

      raise Error, "#{klass} uses class variables (#{klass.class_variables.join(", ")}); worker Ractors can't access them"
    end
  end
end
