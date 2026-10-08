# frozen_string_literal: true

module Kiln
  # Takes a configuration and calls #fire to create a deep-frozen,
  # Ractor-shareable Rack application
  class Application
    def initialize(&block)
      @router = Router.new
      instance_eval(&block) if block
    end

    def routes(&) = @router.draw(&)

    def fire
      Ractor.make_shareable(Dispatcher.new(@router, resolve_controllers))
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
