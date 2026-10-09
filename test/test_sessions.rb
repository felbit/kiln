# frozen_string_literal: true

require "test_helper"

SECRET = "s" * 64

class TestSessionStore < Minitest::Test
  def store(**options) = Kiln::SessionStore.new(secret: SECRET, **options)

  def test_round_trip
    assert_equal({ "user_id" => 42 }, store.decode(store.encode({ "user_id" => 42 })))
  end

  def test_tampered_cookie_is_rejected
    value = store.encode({ "user_id" => 42 })
    tampered = value.dup
    tampered[20] = tampered[20] == "A" ? "B" : "A"

    assert_nil store.decode(tampered)
  end

  def test_other_key_is_rejected
    other = Kiln::SessionStore.new(secret: "t" * 64)
    assert_nil store.decode(other.encode({ "user_id" => 42 }))
  end

  def test_expired_cookie_is_rejected
    assert_nil store.decode(store(max_age: -1).encode({ "user_id" => 42 }))
  end

  def test_garbage_is_ignored
    assert_nil store.decode("not base64 at all!")
    assert_nil store.decode("")
  end

  def test_short_secret_fails_at_boot
    assert_raises(Kiln::Error) { Kiln::SessionStore.new(secret: "too short") }
  end
end

class CounterController < Kiln::Controller
  def bump
    session[:count] = session[:count].to_i + 1
    flash[:notice] = "bumped"
    render plain: session[:count].to_s
  end

  def peek = render(plain: "#{session[:count]}|#{flash[:notice]}")
  def untouched = render(plain: "no session here")
end

class TestSessionsInApp < Minitest::Test
  APP = Kiln::Application.new do
    session secret: SECRET
    routes do
      post "/bump", to: "counter#bump"
      get  "/peek", to: "counter#peek"
      get  "/untouched", to: "counter#untouched"
    end
  end.fire

  def test_untouched_session_sets_no_cookie
    env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/untouched", "QUERY_STRING" => "" }
    _status, headers, _body = APP.call(env)

    refute headers.key?("set-cookie")
  end

  def test_session_and_flash_across_requests_inside_a_ractor
    results = Ractor.new(APP) do |app|
      call = lambda do |verb, path, cookie|
        env = {
          "REQUEST_METHOD" => verb, "PATH_INFO" => path, "QUERY_STRING" => "",
          "HTTP_HOST" => "blog.example", "rack.url_scheme" => "http"
        }
        env["HTTP_COOKIE"] = cookie if cookie
        _status, headers, body = app.call(env)
        [body.join, headers["set-cookie"]&.slice(/\A[^;]+/)]
      end

      first, cookie1 = call.("POST", "/bump", nil)
      second, cookie2 = call.("GET", "/peek", cookie1)
      third, = call.("GET", "/peek", cookie2)
      [first, second, third]
    end.value

    assert_equal ["1", "1|bumped", "1|"], results
  end
end
