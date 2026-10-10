# frozen_string_literal: true

require "test_helper"

class TestConventions < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def app
    Kiln::Application.new(root: File.join(FIXTURES, "conventions_app")) do
      routes { get "/admin", to: "admin#index" }
    end.fire
  end

  def body(fired, path)
    fired.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => path, "QUERY_STRING" => "" })[2].each.to_a.join
  end

  def test_conventions_and_load_order
    fired = app

    assert_equal "<p>hello from a model</p>\n", body(fired, "/admin")
    assert_equal "User-agent: *\n", body(fired, "/robots.txt")
    assert_equal Encoding::UTF_8, body(fired, "/admin").encoding
  end

  def test_conventional_app_inside_a_ractor
    fired = app
    assert Ractor.shareable?(fired)

    html = Ractor.new(fired) do |a|
      a.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => "/admin", "QUERY_STRING" => "" })[2].each.to_a.join
    end.value

    assert_equal "<p>hello from a model</p>\n", html
  end

  def test_class_state_in_a_model_fails_at_boot
    error = assert_raises(Kiln::Error) do
      Kiln::Application.new(root: File.join(FIXTURES, "stateful_app")).fire
    end
    assert_match "CachingThing", error.message
  end

  def test_missing_root
    assert_raises(Kiln::Error) { Kiln::Application.new(root: "/no/such/kiln/app") }
  end
end
