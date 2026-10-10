# frozen_string_literal: true

require "test_helper"
require "kiln/generators/app"
require "tmpdir"
require "stringio"
require "prism"

class TestAppGenerator < Minitest::Test
  def setup
    @parent = Dir.mktmpdir
  end

  def teardown = FileUtils.rm_rf(@parent)

  def generate(name, **options)
    Kiln::Generators::App.new(File.join(@parent, name), out: StringIO.new, **options).run(bundle: false)
    File.join(@parent, name)
  end

  def test_generates_the_layout
    app = generate("demo_blog", kiln_path: "/src/kiln")

    %w[config.ru kino.rb .gitignore .env .env.example config/application.rb
       app/controllers/home_controller.rb app/models/.keep db/migrate/.keep
       public/css/app.css test/test_helper.rb].each do |file|
      assert File.exist?(File.join(app, file)), "#{file} should exist"
    end
  end

  def test_renders_tt_templates
    app = generate("demo_blog", kiln_path: "/src/kiln")

    assert_includes File.read(File.join(app, "config/application.rb")), "module DemoBlog"
    assert_includes File.read(File.join(app, "Gemfile")), %(gem "kiln", path: "/src/kiln")
    assert_match(/\AKILN_SECRET_KEY=\h{128}\z/, File.read(File.join(app, ".env")).lines.last.chomp)
  end

  def test_copies_views_verbatim
    app = generate("demo_blog")

    assert_includes File.read(File.join(app, "app/views/layouts/application.html.erb")), "<%= yield %>"
  end

  def test_env_file_is_private
    app = generate("demo_blog")

    assert_equal 0o600, File.stat(File.join(app, ".env")).mode & 0o777
  end

  def test_generated_ruby_is_valid
    app = generate("demo_blog")

    Dir.glob("**/*.rb", base: app).push("config.ru").each do |file|
      assert Prism.parse_file(File.join(app, file)).success?, "#{file} has a syntax error"
    end
  end

  def test_rejects_bad_names
    assert_raises(Kiln::Error) { generate("My-Blog") }
    assert_raises(Kiln::Error) { generate("set") }
  end

  def test_refuses_existing_directory
    generate("demo_blog")
    assert_raises(Kiln::Error) { generate("demo_blog") }
  end
end
