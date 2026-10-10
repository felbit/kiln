# frozen_string_literal: true

require "test_helper"
require "kiln/app_loader"
require "kiln/database_tasks"
require "tmpdir"

class TestEnv < Minitest::Test
  def with_env_file(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".env")
      File.write(path, content)
      yield path
    end
  ensure
    %w[KILN_TEST_A KILN_TEST_B KILN_TEST_C].each { ENV.delete(it) }
  end

  def test_loads_values_and_strips_quotes
    with_env_file(%(# a comment\nKILN_TEST_A=plain\nexport KILN_TEST_B="quoted value"\n)) do |path|
      Kiln::Env.load(path)

      assert_equal "plain", ENV.fetch("KILN_TEST_A")
      assert_equal "quoted value", ENV.fetch("KILN_TEST_B")
    end
  end

  def test_real_environment_wins
    ENV["KILN_TEST_C"] = "from the environment"
    with_env_file("KILN_TEST_C=from the file\n") do |path|
      Kiln::Env.load(path)

      assert_equal "from the environment", ENV.fetch("KILN_TEST_C")
    end
  end

  def test_malformed_line_is_an_error
    with_env_file("this is not an assignment\n") do |path|
      error = assert_raises(Kiln::Error) { Kiln::Env.load(path) }
      assert_match ":1:", error.message
    end
  end

  def test_missing_file_is_skipped
    assert_nil Kiln::Env.load("/no/such/.env")
  end
end

class TestAppLoader < Minitest::Test
  CLI_APP = File.expand_path("fixtures/cli_app", __dir__)

  def test_finds_root_from_a_subdirectory
    assert_equal CLI_APP, Kiln::AppLoader.find_root(File.join(CLI_APP, "config"))
  end

  def test_loads_the_configured_app_unfired
    app = Kiln::AppLoader.load(CLI_APP)

    assert_equal "postgres://example/cli_app", app.database_url
    assert_equal File.join(File.realpath(CLI_APP), "db/migrate"), app.migrations_path
  end

  def test_outside_an_app
    Dir.mktmpdir do |dir|
      assert_nil Kiln::AppLoader.find_root(dir)
      assert_raises(Kiln::Error) { Kiln::AppLoader.load(dir) }
    end
  end
end

class TestDatabaseTasks < Minitest::Test
  def test_connection_options_from_a_url
    options = Kiln::DatabaseTasks.connection_options("postgres://kiln:secret@db.example:6543/blog_development")

    assert_equal "kiln", options[:user]
    assert_equal "secret", options[:password]
    assert_equal "db.example", options[:host]
    assert_equal "6543", options[:port]
    assert_equal "blog_development", options[:dbname]
  end
end
