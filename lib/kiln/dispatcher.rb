# frozen_string_literal: true

module Kiln
  # Serving the Rack app via Kino
  class Dispatcher
    def initialize(router, controllers)
      @router = router
      @controllers = controllers
    end

    def call(env)
      match = @router.recognize(env["REQUEST_METHOD"], env["PATH_INFO"])
      return not_found unless match

      controller = @controllers.fetch(match.route.controller)
      controller.new(env, match.params).process(match.route.action)
    end

    private

    def not_found
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not Found"]]
    end
  end
end
