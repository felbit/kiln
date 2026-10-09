# frozen_string_literal: true

module Kiln
  # Takes a configuration and calls #fire to create a deep-frozen,
  # Ractor-shareable Rack application
  class Application
    LOAD_ORDER = %w[models controllers].freeze

    def initialize(root: nil, &block)
      @root = root && resolve_root(root)
      @router = Router.new
      @database = nil
      @views_path = nil
      @static_root = nil
      @session_options = nil
      @trusted_origins = []
      instance_eval(&block) if block
    end

    attr_reader :root

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

    def migrations_path = @root && File.join(@root, "db/migrate")

    def fire
      load_app_code
      @database&.verify!
      runtime = Runtime.new(
        database: @database,
        views: views_path&.then { View.compile(it) },
        cross_origin_protection: CrossOriginProtection.new(trusted_origins: @trusted_origins),
        sessions: @session_options && SessionStore.new(**@session_options),
        static: static_root&.then { Static.new(it) }
      )

      # evaluating `resolve_controllers` here instead of inline for the order of
      # checks: load code > verify db > build runtime > check controllers
      #   > check app classes > fire
      controllers = resolve_controllers
      app_modules.each { check_module_state!(it) }
      Ractor.make_shareable(Dispatcher.new(@router, controllers, runtime))
    end

    private

    def views_path = @views_path || conventional("app/views")
    def static_root = @static_root || conventional("public")

    def conventional(relative)
      return unless @root

      path = File.join(@root, relative)
      path if Dir.exist?(path)
    end

    def resolve_root(root)
      File.realpath(root)
    rescue Errno::ENOENT, Errno::ENOTDIR
      raise Error, "application root #{root} does not exist"
    end

    def load_app_code
      return unless @root

      LOAD_ORDER.each do |dir|
        base = File.join(@root, "app", dir)
        files = Dir.glob("**/*.rb", base:).sort_by do |rel|
          [rel.start_with?("application_") ? 0 : 1, rel.count("/"), rel]
        end
        files.each { require File.join(base, it) }
      end
    end

    def app_modules
      return [] unless @root

      app_dir = File.join(@root, "app") + "/"
      ObjectSpace.each_object(Module).select do |mod|
        name = mod.name or next false
        file, = Object.const_source_location(name)
        file&.start_with?(app_dir)
      rescue NameError
        false
      end
    end

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
      klass.ancestors.take_while { it != Controller }.each { check_module_state!(it) }
    end

    def check_module_state!(mod)
      mod.instance_variables.each do |ivar|
        value = mod.instance_variable_get(ivar)
        next if Ractor.shareable?(value)

        raise Error, "#{mod} holds class-level state in #{ivar} (#{value.class}); " \
                     "worker Ractors can't read it. Keep state in the database or per request."
      end
      return if mod.class_variables(false).empty?

      raise Error, "#{mod} uses class variables (#{mod.class_variables(false).join(', ')}); " \
                   "worker Ractors can't access them"
    end
  end
end
