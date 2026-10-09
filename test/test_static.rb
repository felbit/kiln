# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PagesController < Kiln::Controller
  def show = render(plain: "routed")
end

class TestStatic < Minitest::Test
  def setup
    @base = Dir.mktmpdir
    @dir = File.join(@base, "public")
    write "css/app.css", "body { color: red; }"
    write "my file.txt", "spaces work"
    write ".env", "SECRET=1"
    File.write(File.join(@base, "outside.txt"), "not public")
    File.symlink(File.join(@base, "outside.txt"), File.join(@dir, "leak.txt"))
  end

  def teardown = FileUtils.rm_rf(@base)

  def write(name, body)
    path = File.join(@dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
  end

  def app
    dir = @dir
    Kiln::Application.new do
      static_files dir
      routes { get "/pages/:id", to: "pages#show" }
    end.fire
  end

  def request(path, verb: "GET", headers: {})
    env = { "REQUEST_METHOD" => verb, "PATH_INFO" => path, "QUERY_STRING" => "" }.merge(headers)
    status, response_headers, body = app.call(env)
    [status, response_headers, body.each.to_a.join]
  end

  def test_serves_a_file
    status, headers, body = request("/css/app.css")

    assert_equal 200, status
    assert_equal "text/css; charset=utf-8", headers["content-type"]
    assert_equal "body { color: red; }", body
  end

  def test_unchanged_file_returns_304
    _status, headers, = request("/css/app.css")
    status, _headers, body = request("/css/app.css", headers: { "HTTP_IF_NONE_MATCH" => headers["etag"] })

    assert_equal 304, status
    assert_empty body
  end

  def test_head_sends_headers_only
    status, headers, body = request("/css/app.css", verb: "HEAD")

    assert_equal 200, status
    assert_equal "20", headers["content-length"]
    assert_empty body
  end

  def test_percent_encoded_paths
    assert_equal "spaces work", request("/my%20file.txt")[2]
  end

  def test_never_serves_dotfiles_traversal_or_escaping_symlinks
    %w[/.env /../outside.txt /css/../../outside.txt /leak.txt].each do |path|
      assert_equal 404, request(path)[0], "#{path} must not be served"
    end
  end

  def test_post_is_not_served_as_a_file
    assert_equal 404, request("/css/app.css", verb: "POST")[0]
  end

  def test_routes_still_work
    assert_equal "routed", request("/pages/1")[2]
  end

  def test_serving_inside_a_ractor
    body = Ractor.new(app) do |a|
      env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/css/app.css", "QUERY_STRING" => "" }
      a.call(env)[2].each.to_a.join
    end.value

    assert_equal "body { color: red; }", body
  end
end
