require "test_helper"

class TestRouter < Minitest::Test
  def router
    Kiln::Router.new.draw do
      get  "/", to: "home#index"
      get  "/posts/:id", to: "posts#show"
      post "/posts", to: "posts#create"
      get  "/posts/:post_id/comments/:id", to: "comments#show"
    end
  end

  def test_static_route
    m = router.recognize("GET", "/")
    assert_equal "home", m.route.controller
    assert_equal :index, m.route.action
    assert_equal({}, m.params)
  end

  def test_dynamic_segments
    m = router.recognize("GET", "/posts/2/comments/1")
    assert_equal({ "post_id" => "2", "id" => "1" }, m.params)
  end

  def test_verb_matters
    assert_nil router.recognize("GET", "/posts")
    refute_nil router.recognize("POST", "/posts")
  end

  def test_no_partial_matches
    assert_nil router.recognize("GET", "/posts/2/edit")
  end

  def test_invalid_target
    assert_raises(ArgumentError) { Kiln::Router.new.draw { get "/", to: "home" } }
  end
end
