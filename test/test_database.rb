# frozen_string_literal: true

require "test_helper"

DATABASE_URL = ENV.fetch("DATABASE_URL", "postgres://kiln:kiln@localhost:5432/kiln_test")

class EchoController < Kiln::Controller
  def show = render(plain: db.query_one("SELECT $1::text AS word", params["word"])["word"])
  def pid  = render(plain: db.query_one("SELECT pg_backend_pid() AS pid")["pid"])

  def abandon_transaction
    db.raw.exec("BEGIN")
    raise "boom"
  end
end

class NoDbController < Kiln::Controller
  def index = render(plain: db.query_one("SELECT 1")["?column?"])
end

class TestDatabase < Minitest::Test
  def app_with_db
    Kiln::Application.new do
      database url: DATABASE_URL
      routes do
        get "/echo/:word", to: "echo#show"
        get "/pid", to: "echo#pid"
        get "/abandon", to: "echo#abandon_transaction"
      end
    end.fire
  end

  def env(path) = { "REQUEST_METHOD" => "GET", "PATH_INFO" => path }

  def teardown
    Kiln::Database.new(url: DATABASE_URL).disconnect
  end

  def test_query_inside_a_ractor
    body = Ractor.new(app_with_db, env("/echo/kiln")) { |a, e| a.call(e)[2].join }.value
    assert_equal "kiln", body
  end

  def test_connection_is_reused_within_a_ractor
    pids = Ractor.new(app_with_db, env("/pid")) do |a, e|
      2.times.map { a.call(e)[2].join }
    end.value

    assert_equal 1, pids.uniq.size
  end

  def test_each_ractor_has_its_own_connection
    app = app_with_db
    pids = 3.times.map { Ractor.new(app, env("/pid")) { |a, e| a.call(e)[2].join } }.map(&:value)

    assert_equal 3, pids.uniq.size
  end

  def test_abandoned_transaction_is_rolled_back
    app = app_with_db
    assert_raises(RuntimeError) { app.call(env("/abandon")) }

    status = Kiln::Database.new(url: DATABASE_URL).connection.raw.transaction_status
    assert_equal PG::PQTRANS_IDLE, status
  end

  def test_db_without_configuration
    app = Kiln::Application.new { routes { get "/", to: "no_db#index" } }.fire
    assert_raises(Kiln::Error) { app.call(env("/")) }
  end

  def test_unreachable_database_fails_at_fire
    error = assert_raises(Kiln::Error) do
      Kiln::Application.new do
        database url: "postgres://kiln:kiln@localhost:1/nope"
        routes { get "/pid", to: "echo#pid" }
      end.fire
    end
    assert_match "can't connect", error.message
  end
end
