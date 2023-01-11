# frozen_string_literal: true

require "hq/graphql/enum/filter_operation"

module HQ
  module GraphQL
    module FilterOperations
      class Operation
        attr_reader :name, :arel, :check_for_null, :sanitize

        def initialize(name:, arel:, check_for_null: false, sanitize: nil)
          @name           = name
          @arel           = arel
          @check_for_null = check_for_null
          @sanitize       = sanitize
        end

        def sanitize_value(value)
          sanitize ? sanitize.call(value) : value
        end

        def to_arel(table:, column_name:, value:, array_values:, column_value:)
          sanitized_value = sanitize_value(arel == :in ? array_values : value)

          if arel.is_a?(Proc)
            return arel.call(table: table, column_name: column_name, value: sanitized_value)
          end

          if sanitized_value.nil?
            return table[column_name].send(arel, table[column_value.name])
          end

          expression = table[column_name].send(arel, sanitized_value)

          if check_for_null
            expression = expression.or(table[column_name].eq(nil))
          end

          expression
        end
      end

      OPERATIONS = [
        EQUAL = Operation.new(name: "EQUAL", arel: :eq),
        IN = Operation.new(name: "IN", arel: :in),
        NOT_EQUAL = Operation.new(name: "NOT_EQUAL", arel: :not_eq, check_for_null: true),
        LIKE = Operation.new(name: "LIKE", arel: :matches, sanitize: ->(value) { "%#{ActiveRecord::Base.sanitize_sql_like(value)}%" }),
        NOT_LIKE = Operation.new(name: "NOT_LIKE", arel: :does_not_match, check_for_null: true, sanitize: ->(value) { "%#{ActiveRecord::Base.sanitize_sql_like(value)}%" }),
        GREATER_THAN = Operation.new(name: "GREATER_THAN", arel: :gt),
        LESS_THAN = Operation.new(name: "LESS_THAN", arel: :lt),
        WITH = Operation.new(
          name: "WITH",
          arel: ->(table:, column_name:, value:) do
            if value.casecmp("t") == 0 || value.casecmp("true") == 0
              table[column_name].not_eq(nil)
            else
              table[column_name].eq(nil)
            end
          end
        )
      ]
    end
  end
end
