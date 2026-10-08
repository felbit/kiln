# frozen_string_literal: true

module Kiln
  # Serving the Rack app via Kino
  class Dispatcher
    def initialize(router, controllers, database)
      @router = router
      @controllers = controllers
      @database = database
    end

    def call(env)
      match = @router.recognize(env["REQUEST_METHOD"], env["PATH_INFO"])
      return not_found unless match

      controller = @controllers.fetch(match.route.controller)
      controller.new(env, match.params, @database).process(match.route.action)
    ensure
      @database&.clean_up_after_request
    end

    private

    def not_found
      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not Found"]]
    end
  end
end
