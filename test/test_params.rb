# frozen_string_literal: true

require "test_helper"
require "stringio"

class FormsController < Kiln::Controller
  def show = render(plain: "#{params["id"]}|#{nested_params("post")["title"]}")
  def destroy = render(plain: "deleted #{params["id"]}")
end

class TestParams < Minitest::Test
  APP = Kiln::Application.new do
    routes do
      get "/forms/:id", to: "forms#show"
      post "/forms/:id", to: "forms#show"
      delete "/forms/:id", to: "forms#destroy"
    end
  end.fire

  def request(verb, path, query: "", form: nil)
    env = { "REQUEST_METHOD" => verb, "PATH_INFO" => path, "QUERY_STRING" => query }
    if form
      env["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
      env["CONTENT_LENGTH"] = form.bytesize.to_s
      env["rack.input"] = StringIO.new(form)
    end
    status, _headers, body = APP.call(env)
    [status, body.join]
  end

  def test_nested_form_params
    assert_equal [200, "1|Hello"], request("POST", "/forms/1", form: "post%5Btitle%5D=Hello")
  end

  def test_path_params_win_over_query_params
    assert_equal [200, "5|"], request("GET", "/forms/5", query: "id=9")
  end

  def test_method_override_from_post
    assert_equal [200, "deleted 3"], request("POST", "/forms/3", form: "_method=delete")
  end

  def test_no_method_override_from_get
    assert_equal [200, "3|"], request("GET", "/forms/3", query: "_method=delete")
  end

  def test_string_where_hash_expected
    assert_equal [200, "1|"], request("POST", "/forms/1", form: "post=oops")
  end

  def test_conflicting_param_types
    status, = request("GET", "/forms/1", query: "a[]=1&a[b]=2")
    assert_equal 400, status
  end

  def test_invalid_utf8
    status, = request("GET", "/forms/1", query: "q=%FF")
    assert_equal 400, status
  end

  def test_form_too_large
    status, = request("POST", "/forms/1", form: "x=#{'a' * (1024 * 1024)}")
    assert_equal 413, status
  end

  def test_form_params_inside_a_ractor
    result = Ractor.new(APP) do |app|
      form = "post%5Btitle%5D=From+a+Ractor"
      env = {
        "REQUEST_METHOD" => "POST", "PATH_INFO" => "/forms/7", "QUERY_STRING" => "",
        "CONTENT_TYPE" => "application/x-www-form-urlencoded",
        "CONTENT_LENGTH" => form.bytesize.to_s, "rack.input" => StringIO.new(form)
      }
      app.call(env)[2].join
    end.value

    assert_equal "7|From a Ractor", result
  end
end
