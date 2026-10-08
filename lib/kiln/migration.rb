# frozen_string_literal: true

module Kiln
  # Base class for database migrations.
  #
  # @example
  #   class CreatePosts < Kiln::Migration
  #     def up
  #       execute <<~SQL
  #         CREATE TABLE posts (
  #           id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  #           title      text NOT NULL,
  #           created_at timestamptz NOT NULL DEFAULT now()
  #         )
  #       SQL
  #     end
  #
  #     def down
  #       execute "DROP TABLE posts"
  #     end
  #   end
  class Migration
    class IrreversibleError < Kiln::Error; end

    def initialize(connection)
      @connection = connection
    end

    def up
      raise NotImplementedError, "#{self.class} must define #up"
    end

    def down
      raise IrreversibleError, "#{self.class} can't be rolled back (no #down defined)"
    end

    def transaction? = true

    def execute(sql) = @connection.exec(sql)

    def query(sql, *binds) = @connection.exec_params(sql, binds).to_a
  end
end
