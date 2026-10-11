# frozen_string_literal: true

module Kiln
  class ErrorPages
    def initialize(environment:, root: nil, routes: [])
      @development = environment.development?
      @root = root
      @routes = routes.map { "#{it.verb.ljust(7)} #{it.path}  ->  #{it.controller}##{it.action}" }
      @not_found_html = static_page("404") || "<h1>Not Found</h1>"
      @error_html = static_page("500") || "<h1>Something went wrong</h1>"
    end

    def not_found(env)
      html(404, @development ? development_not_found(env) : @not_found_html)
    end

    def server_error(error, env)
      html(500, @development ? development_error(error, env) : @error_html)
    end

    private

    def html(status, body) = [status, { "content-type" => "text/html; charset=utf-8" }, [body]]

    def static_page(code)
      path = @root && File.join(@root, "public", "#{code}.html")
      File.read(path, encoding: "UTF-8") if path && File.file?(path)
    end

    def development_not_found(env)
      page("No route matches #{h(env['REQUEST_METHOD'])} #{h(env['PATH_INFO'])}",
           "<h2>Routes</h2><pre>#{h(@routes.join("\n"))}</pre>")
    end

    def development_error(error, env)
      frames = Array(error.backtrace).first(40).map do |line|
        if @root && line.start_with?("#{@root}/")
          %(<li class="app">#{h(line.delete_prefix("#{@root}/"))}</li>)
        else
          "<li>#{h(line)}</li>"
        end
      end

      page("#{h(error.class)} in #{h(env['REQUEST_METHOD'])} #{h(env['PATH_INFO'])}",
           %(<p class="message">#{h(error.message)}</p><h2>Backtrace</h2><ol>#{frames.join}</ol>))
    end

    def page(title, content)
      <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>#{title}</title>
            <style>
              body { font: 15px/1.5 system-ui, sans-serif; margin: 2rem; color: #222; }
              h1 { color: #b3261e; font-size: 1.4rem; }
              .message { background: #fdecea; padding: 1rem; white-space: pre-wrap; }
              ol, pre { font: 13px/1.6 ui-monospace, monospace; }
              li { color: #888; }
              li.app { color: #222; font-weight: bold; }
            </style>
          </head>
          <body><h1>#{title}</h1>#{content}</body>
        </html>
      HTML
    end

    def h(value) = View.escape(value)
  end
end
