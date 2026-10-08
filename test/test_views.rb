# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class ArticlesController < Kiln::Controller
  def index
    @title = "<script>alert(1)</script>"
  end

  def bare
    @title = "Bare"
    render :index, layout: false
  end

  def broken = render("articles/broken")
end

class TestViews < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    write "layouts/application.html.erb", "<main><%= yield %></main>"
    write "articles/index.html.erb", "<h1><%= @title %></h1>"
    write "articles/broken.html.erb", "<p>\n<% raise 'boom' %>\n</p>"
  end

  def teardown = FileUtils.rm_rf(@dir)

  def write(name, body)
    path = File.join(@dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
  end

  def app
    dir = @dir
    Kiln::Application.new do
      views dir
      routes do
        get "/articles", to: "articles#index"
        get "/bare",     to: "articles#bare"
        get "/broken",   to: "articles#broken"
      end
    end.fire
  end

  def body(path) = app.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => path })[2].join

  def test_implicit_render_escapes_and_uses_layout
    assert_equal "<main><h1>&lt;script&gt;alert(1)&lt;/script&gt;</h1></main>", body("/articles")
  end

  def test_render_without_layout
    assert_equal "<h1>Bare</h1>", body("/bare")
  end

  def test_errors_point_into_the_template
    error = assert_raises(RuntimeError) { body("/broken") }
    assert_match "articles/broken.html.erb:2", error.backtrace.join("\n")
  end

  def test_rendering_inside_a_ractor
    fired = app
    assert Ractor.shareable?(fired)

    html = Ractor.new(fired) do |a|
      a.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => "/articles" })[2].join
    end.value

    assert_equal "<main><h1>&lt;script&gt;alert(1)&lt;/script&gt;</h1></main>", html
  end
end
