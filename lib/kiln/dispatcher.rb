# frozen_string_literal: true

module Kiln
  # Serving the Rack app via Kino
  class Dispatcher
    def initialize(router, controllers, runtime)
      @router = router
      @controllers = controllers
      @runtime = runtime
    end

    def call(env)
      if (file = @runtime.static&.call(env))
        return file
      end

      return forbidden unless @runtime.cross_origin_protection.allowed?(env)

      params = Params.parse(env)
      match = @router.recognize(Params.verb(env, params), env["PATH_INFO"])
      return @runtime.errors.not_found(env) unless match

      controller = @controllers.fetch(match.route.controller)
      controller.new(env, params.merge(match.params), @runtime).process(match.route.action)
    rescue Params::Error => e
      [e.status, { "content-type" => "text/plain; charset=utf-8" }, [e.message]]
    rescue StandardError => e
      raise if @runtime.environment.test?

      warn "#{e.class}: #{e.message}", *Array(e.backtrace).first(10).map { "  #{it}" }
      @runtime.errors.server_error(e, env)
    ensure
      @runtime.database&.clean_up_after_request
    end


    private

    def forbidden
      [403, { "content-type" => "text/plain; charset=utf-8" }, ["Cross-origin request blocked"]]
    end
  end
end
