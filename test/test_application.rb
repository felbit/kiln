# frozen_string_literal: true

require "test_helper"

class GreetingsController < Kiln::Controller
  def hello = render(plain: "hello #{params["name"]}")

  def twice
    render plain: "one"
    render plain: "two"
  end
end

class StatefulController < Kiln::Controller
  @cache = {}

  def index = render(plain: "never reached")
end

class TestApplication < Minitest::Test
  def app
    Kiln::Application.new do
      routes do
        get "/hello/:name", to: "greetings#hello"
        get "/twice",       to: "greetings#twice"
      end
    end.fire
  end

  def env(path, verb = "GET") = { "REQUEST_METHOD" => verb, "PATH_INFO" => path }

  def test_fired_app_is_shareable
    assert Ractor.shareable?(app)
  end

  def test_request_inside_a_ractor
    status, body = Ractor.new(app, env("/hello/kiln")) do |a, e|
      s, _headers, b = a.call(e)
      [s, b.join]
    end.value

    assert_equal 200, status
    assert_equal "hello kiln", body
  end

  def test_not_found
    status, = app.call(env("/nope"))
    assert_equal 404, status
  end

  def test_double_render
    assert_raises(Kiln::Controller::DoubleRenderError) { app.call(env("/twice")) }
  end

  def test_missing_controller
    error = assert_raises(Kiln::Error) do
      Kiln::Application.new { routes { get "/", to: "missing#index" } }.fire
    end
    assert_match "MissingController", error.message
  end

  def test_base_class_methods_are_not_actions
    assert_raises(Kiln::Error) do
      Kiln::Application.new { routes { get "/", to: "greetings#render" } }.fire
    end
  end

  def test_class_level_state_is_rejected
    error = assert_raises(Kiln::Error) do
      Kiln::Application.new { routes { get "/", to: "stateful#index" } }.fire
    end
    assert_match "@cache", error.message
  end

  def test_fired_app_rejects_new_routes
    application = Kiln::Application.new { routes { get "/hello/:name", to: "greetings#hello" } }
    application.fire

    assert_raises(FrozenError) { application.routes { get "/late", to: "greetings#hello" } }
  end
end
