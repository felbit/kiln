# frozen_string_literal: true

require "test_helper"
require "kiln/migrator"
require "tmpdir"
require "stringio"

class TestMigrator < Minitest::Test
  BASE_URL = ENV.fetch("DATABASE_URL", "postgres://kiln:kiln@localhost:5432/kiln_test")
  SCHEMA = "kiln_migrator_test"
  URL = "#{BASE_URL}#{BASE_URL.include?('?') ? '&' : '?'}options=-csearch_path%3D#{SCHEMA}"

  def setup
    @dir = Dir.mktmpdir
    @out = StringIO.new
    admin { it.exec("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE; CREATE SCHEMA #{SCHEMA}") }
  end

  def teardown
    admin { it.exec("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE") }
    FileUtils.rm_rf(@dir)
  end

  def admin
    conn = PG.connect(BASE_URL)
    conn.exec("SET client_min_messages TO warning")
    yield conn
  ensure
    conn&.close
  end

  def migrator = Kiln::Migrator.new(url: URL, path: @dir, out: @out)

  def write(filename, body) = File.write(File.join(@dir, filename), body)

  def table?(name)
    conn = PG.connect(URL)
    !conn.exec_params("SELECT to_regclass($1) AS t", [name]).first["t"].nil?
  ensure
    conn&.close
  end

  def test_applies_pending_migrations_in_order
    write "20260101000001_create_widgets.rb", <<~RUBY
      class CreateWidgets < Kiln::Migration
        def up = execute("CREATE TABLE widgets (id bigint PRIMARY KEY)")
        def down = execute("DROP TABLE widgets")
      end
    RUBY
    write "20260101000002_add_color_to_widgets.rb", <<~RUBY
      class AddColorToWidgets < Kiln::Migration
        def up = execute("ALTER TABLE widgets ADD COLUMN color text")
        def down = execute("ALTER TABLE widgets DROP COLUMN color")
      end
    RUBY

    migrator.migrate

    assert table?("widgets")
    assert_equal %w[up up], migrator.status.map(&:first)
  end

  def test_migrate_twice_is_a_no_op
    write "20260101000001_create_gizmos.rb", <<~RUBY
      class CreateGizmos < Kiln::Migration
        def up = execute("CREATE TABLE gizmos (id bigint)")
      end
    RUBY

    migrator.migrate
    migrator.migrate

    assert_includes @out.string, "Nothing to migrate."
  end

  def test_failed_migration_leaves_no_trace
    write "20260101000001_half_done.rb", <<~RUBY
      class HalfDone < Kiln::Migration
        def up
          execute "CREATE TABLE half_done (id bigint)"
          raise "boom"
        end
      end
    RUBY

    assert_raises(RuntimeError) { migrator.migrate }

    refute table?("half_done")
    assert_equal %w[down], migrator.status.map(&:first)
  end

  def test_rollback_reverts_the_last_migration
    write "20260101000001_create_sprockets.rb", <<~RUBY
      class CreateSprockets < Kiln::Migration
        def up = execute("CREATE TABLE sprockets (id bigint)")
        def down = execute("DROP TABLE sprockets")
      end
    RUBY

    migrator.migrate
    migrator.rollback

    refute table?("sprockets")
    assert_equal %w[down], migrator.status.map(&:first)
  end

  def test_irreversible_migration_stays_applied
    write "20260101000001_create_cogs.rb", <<~RUBY
      class CreateCogs < Kiln::Migration
        def up = execute("CREATE TABLE cogs (id bigint)")
      end
    RUBY

    migrator.migrate
    assert_raises(Kiln::Migration::IrreversibleError) { migrator.rollback }

    assert table?("cogs")
    assert_equal %w[up], migrator.status.map(&:first)
  end
end
