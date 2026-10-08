# frozen_string_literal: true

module Kiln
  class Database
    # Ractor safe, threat-owned wrapper around PG::Connection
    class Connection
      attr_reader :raw

      def initialize(raw)
        @raw = raw
      end

      # Runs a query and returns all rows as hashes with string keys and values.
      # Potentially empty.
      def query(sql, *binds) = @raw.exec_params(sql, binds).to_a

      # Runs a query and returns the first row, or nil.
      def query_one(sql, *binds) = query(sql, *binds).first

      # Runs a statement and returns the number of affected rows.
      def execute(sql, *binds) = @raw.exec_params(sql, binds).cmd_tuples

      # Reconnect if the connection was lost
      def transaction
        @raw.transaction { yield self }
      end

      def ensure_alive!
        @raw.reset if @raw.finished? || @raw.status == PG::CONNECTION_BAD
      end

      def clean_up!
        case @raw.transaction_status
        when PG::PQTRANS_INTRANS, PG::PQTRANS_INERROR then @raw.exec("ROLLBACK")
        end
      end

      def close = @raw.close
    end
  end
end
