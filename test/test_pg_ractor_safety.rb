require "test_helper"
require "pg"

class TestPostgresInRactors < Minitest::Test
  URL = ENV.fetch("DATABASE_URL", "postgres://kiln:kiln@localhost:5432/kiln_test")

  def test_query_inside_a_ractor
    result = Ractor.new(URL) do |url|
      conn = PG.connect(url)
      conn.exec_params("SELECT $1::int + 1 AS answer", [41]).first["answer"]
    ensure
      conn&.close
    end.value

    assert_equal "42", result
  end

  def test_parallel_ractors_with_own_connections
    ractors = 4.times.map do |i|
      Ractor.new(URL, i) do |url, n|
        conn = PG.connect(url)
        conn.exec_params("SELECT pg_backend_pid() AS pid, $1::int AS n", [n]).first
      ensure
        conn&.close
      end
    end

    rows = ractors.map(&:value)

    assert_equal [0, 1, 2, 3], rows.map { it["n"].to_i }
    assert_equal 4, rows.map { it["pid"] }.uniq.size
  end
end
