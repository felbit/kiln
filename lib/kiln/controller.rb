# frozen_string_literal: true

module Kiln
  # Base class for application controllers
  class Controller
    class DoubleRenderError < Kiln::Error; end

    attr_reader :env, :params

    def initialize(env, params)
      @env = env
      @params = params
      @response = nil
    end

    def render(plain: nil, html: nil, status: 200)
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
      @response || [204, {}, []]
    end

    private

    def commit(status, headers, body)
      raise DoubleRenderError, "#{self.class} tried to respond twice in one request" if @response

      @response = [status, headers, body]
    end
  end
end
