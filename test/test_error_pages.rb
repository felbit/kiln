# frozen_string_literal: true

require "test_helper"

class FailingController < Kiln::Controller
  def boom = raise("kaboom <script>")
end

class TestErrorPages < Minitest::Test
  ERRORS_APP = File.expand_path("fixtures/errors_app", __dir__)

  def app(environment, root: nil)
    Kiln::Application.new(root:, environment:) do
      routes { get "/boom", to: "failing#boom" }
    end.fire
  end

  def request(fired, path)
    status, _headers, body = fired.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => path, "QUERY_STRING" => "" })
    [status, body.each.to_a.join]
  end

  def test_development_shows_the_exception_escaped
    status, body = nil
    _out, err = capture_io { status, body = request(app("development"), "/boom") }

    assert_equal 500, status
    assert_includes body, "RuntimeError"
    assert_includes body, "kaboom &lt;script&gt;"
    refute_includes body, "<script>"
    assert_includes err, "kaboom"
  end

  def test_development_404_lists_routes
    status, body = request(app("development"), "/nope")

    assert_equal 404, status
    assert_includes body, "/boom"
  end

  def test_production_uses_custom_pages
    fired = app("production", root: ERRORS_APP)
    status, body = nil
    capture_io { status, body = request(fired, "/boom") }

    assert_equal 500, status
    assert_equal File.read(File.join(ERRORS_APP, "public/500.html")), body
    assert_equal File.read(File.join(ERRORS_APP, "public/404.html")), request(fired, "/nope")[1]
  end

  def test_production_never_shows_internals
    body = nil
    capture_io { body = request(app("production"), "/boom")[1] }

    refute_includes body, "kaboom"
    refute_includes body, "RuntimeError"
  end

  def test_test_environment_reraises
    assert_raises(RuntimeError) { request(app("test"), "/boom") }
  end

  def test_unknown_environment
    assert_raises(Kiln::Error) { Kiln::Environment.new(name: "staging") }
  end

  def test_error_page_inside_a_ractor
    status, err = Ractor.new(app("production")) do |a|
      $stderr = StringIO.new
      response = a.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => "/boom", "QUERY_STRING" => "" })
      [response[0], $stderr.string]
    end.value

    assert_equal 500, status
    assert_includes err, "kaboom"
  end
end
