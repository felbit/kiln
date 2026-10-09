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
      return not_found unless match

      controller = @controllers.fetch(match.route.controller)
      controller.new(env, params.merge(match.params), @runtime).process(match.route.action)
    rescue Params::Error => e
      [e.status, { "content-type" => "text/plain; charset=utf-8" }, [e.message]]
    ensure
      @runtime.database&.clean_up_after_request
    end

    private

    def not_found
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not Found"]]
    end

    def forbidden
      [403, { "content-type" => "text/plain; charset=utf-8" }, ["Cross-origin request blocked"]]
    end
  end
end
