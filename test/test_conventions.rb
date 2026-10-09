# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestConventions < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    write "app/models/greeting.rb", <<~RUBY
      class Greeting
        def self.text = "hello from a model"
      end
    RUBY
    write "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < Kiln::Controller; end
    RUBY
    write "app/controllers/admin_controller.rb", <<~RUBY
      class AdminController < ApplicationController
        def index
          @greeting = Greeting.text
        end
      end
    RUBY
    write "app/views/admin/index.html.erb", "<p><%= @greeting %></p>"
    write "public/robots.txt", "User-agent: *"
  end

  def teardown = FileUtils.rm_rf(@root)

  def write(name, body)
    path = File.join(@root, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
  end

  def app
    Kiln::Application.new(root: @root) do
      routes { get "/admin", to: "admin#index" }
    end.fire
  end

  def body(fired, path) = fired.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => path, "QUERY_STRING" => "" })[2].each.to_a.join

  def test_conventions_and_load_order
    fired = app

    assert_equal "<p>hello from a model</p>", body(fired, "/admin")
    assert_equal "User-agent: *", body(fired, "/robots.txt")
  end

  def test_conventional_app_inside_a_ractor
    fired = app
    assert Ractor.shareable?(fired)

    html = Ractor.new(fired) do |a|
      a.call({ "REQUEST_METHOD" => "GET", "PATH_INFO" => "/admin", "QUERY_STRING" => "" })[2].each.to_a.join
    end.value

    assert_equal "<p>hello from a model</p>", html
  end

  def test_class_state_in_a_model_fails_at_boot
    write "app/models/caching_thing.rb", <<~RUBY
      class CachingThing
        @cache = {}
      end
    RUBY

    error = assert_raises(Kiln::Error) { app }
    assert_match "CachingThing", error.message
  end

  def test_missing_root
    assert_raises(Kiln::Error) { Kiln::Application.new(root: "/no/such/kiln/app") }
  end
end
