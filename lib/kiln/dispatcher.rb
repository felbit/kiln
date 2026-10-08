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
      match = @router.recognize(env["REQUEST_METHOD"], env["PATH_INFO"])
      return not_found unless match

      controller = @controllers.fetch(match.route.controller)
      controller.new(env, match.params, @runtime).process(match.route.action)
    ensure
      @runtime.database&.clean_up_after_request
    end

    private

    def not_found
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not Found"]]
    end
  end
end
