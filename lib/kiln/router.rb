# frozen_string_literal: true

module Kiln
  # Maps HTTP verbs and paths to controller actions.
  #
  # A router has two phases. During boot, routes are collected through a
  # small DSL. When the application is fired, the router is deep-frozen with
  # +Ractor.make_shareable+ so every worker Ractor can read it in parallel.
  # After that, only {#recognize} may be called; defining new routes raises
  # +FrozenError+.
  #
  # @example Defining and recognizing routes
  #   router = Kiln::Router.new.draw do
  #     get  "/",          to: "home#index"
  #     get  "/posts/:id", to: "posts#show"
  #     post "/posts",     to: "posts#create"
  #   end
  #
  #   match = router.recognize("GET", "/posts/123")
  #   match.route.controller # => "posts"
  #   match.route.action     # => :show
  #   match.params           # => { "id" => "123" }
  class Router
    Route = Data.define(:verb, :path, :pattern, :param_names, :controller, :action)
    Match = Data.define(:route, :params)

    # Matches a dynamic path segment such as +:id+ or +:post_id+.
    PARAM = /:([a-z_][a-z0-9_]*)/

    def initialize
      @routes = []
    end

    # Evaluates a block of route definitions in the context of this router.
    #
    # @yield the route definitions, evaluated with +instance_eval+
    # @return [Router] self, so calls can be chained
    def draw(&) = tap { instance_eval(&) }

    def get(path, to:) = add("GET", path, to)
    def post(path, to:) = add("POST", path, to)
    def patch(path, to:) = add("PATCH", path, to)
    def put(path, to:) = add("PUT", path, to)
    def delete(path, to:) = add("DELETE", path, to)

    # Finds the first route matching a request
    #
    # Routes are tried in definition order, so earlier routes win. This
    # method only reads the router and is safe to call from any Ractor once
    # the router is fired.
    #
    # @param verb [String] the HTTP method, e.g. +"GET"+
    # @param path [String] the request path, e.g. +"/posts/123"+
    # @return [Match, nil] the matched route and its params or +nil+
    def recognize(verb, path)
      @routes.each do |route|
        next unless route.verb == verb

        m = route.pattern.match(path) or next
        return Match.new(route:, params: route.param_names.zip(m.captures).to_h)
      end
      nil
    end

    def routes = @routes

    private

    def add(verb, path, target)
      controller, action = target.split("#", 2)
      unless controller && action
        raise ArgumentError, "route target must look like \"posts#index\", got #{target.inspect}"
      end

      @routes << Route.new(
        verb:, path:,
        pattern: Regexp.new("\\A#{Regexp.escape(path).gsub(PARAM, "([^/]+)")}\\z"),
        param_names: path.scan(PARAM).flatten,
        controller:, action: action.to_sym
      )
      self
    end
  end
end
