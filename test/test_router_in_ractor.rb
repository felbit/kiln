# test/test_router_in_ractor.rb
require "test_helper"

class TestRouterInRactor < Minitest::Test
  def fired_router
    Ractor.make_shareable(
      Kiln::Router.new.draw { get "/posts/:id", to: "posts#show" }
    )
  end

  def test_fired_router_is_shareable
    assert Ractor.shareable?(fired_router)
  end

  def test_recognizes_inside_a_ractor
    params = Ractor.new(fired_router) do |router|
      router.recognize("GET", "/posts/123").params
    end.value

    assert_equal({ "id" => "123" }, params)
  end

  def test_fired_router_rejects_new_routes
    assert_raises(FrozenError) { fired_router.get "/late", to: "late#index" }
  end
end
