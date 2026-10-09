# frozen_string_literal: true

require "test_helper"

class TestCrossOriginProtection < Minitest::Test
  def check(method: "POST", fetch_site: nil, origin: nil, host: "blog.example", trusted: [])
    env = { "REQUEST_METHOD" => method, "HTTP_HOST" => host }
    env["HTTP_SEC_FETCH_SITE"] = fetch_site if fetch_site
    env["HTTP_ORIGIN"] = origin if origin
    Kiln::CrossOriginProtection.new(trusted_origins: trusted).allowed?(env)
  end

  def test_safe_methods_are_always_allowed
    assert check(method: "GET", fetch_site: "cross-site")
  end

  def test_same_origin_and_direct_navigation_are_allowed
    assert check(fetch_site: "same-origin")
    assert check(fetch_site: "none")
  end

  def test_cross_site_and_same_site_are_rejected
    refute check(fetch_site: "cross-site", origin: "https://evil.example")
    refute check(fetch_site: "same-site", origin: "https://other.blog.example")
  end

  def test_trusted_origin_is_allowed_cross_site
    assert check(fetch_site: "cross-site", origin: "https://admin.example",
                 trusted: ["https://admin.example"])
  end

  def test_origin_fallback_for_older_browsers
    assert check(origin: "https://blog.example")
    refute check(origin: "https://evil.example")
  end

  def test_null_origin_is_rejected
    refute check(origin: "null")
  end

  def test_requests_without_browser_headers_are_allowed
    assert check
  end
end

class GuardedController < Kiln::Controller
  def create = render(plain: "created")
end

class TestCrossOriginProtectionInApp < Minitest::Test
  APP = Kiln::Application.new do
    routes { post "/things", to: "guarded#create" }
  end.fire

  def test_forged_post_is_blocked_inside_a_ractor
    status, body = Ractor.new(APP) do |app|
      env = {
        "REQUEST_METHOD" => "POST", "PATH_INFO" => "/things", "QUERY_STRING" => "",
        "HTTP_HOST" => "blog.example", "HTTP_SEC_FETCH_SITE" => "cross-site",
        "HTTP_ORIGIN" => "https://evil.example"
      }
      s, _headers, b = app.call(env)
      [s, b.join]
    end.value

    assert_equal 403, status
    assert_equal "Cross-origin request blocked", body
  end
end
