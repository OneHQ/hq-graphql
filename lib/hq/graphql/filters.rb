# frozen_string_literal: true

require "hq/graphql/filter_operations"
require "hq/graphql/util"

module HQ
  module GraphQL
    class Filters
      BOOLEAN_VALUES = ["t", "f", "true", "false"]

      def self.supported?(column)
        !!Filter.class_from_column(column)
      end

      attr_reader :filters, :model

      def initialize(filters, model)
        @filters = Array(filters).map { |filter| Filter.for(filter, table: model.arel_table) }
        @model = model
      end

      def validate!
        filters.each(&:validate)
        errors = filters.map do |filter|
          filter.display_error_message
        end.flatten.uniq

        if errors.any?
          raise ::GraphQL::ExecutionError, errors.join(", ")
        end
      end

      def to_scope
        filters.reduce(model.all) do |s, filter|
          s.where(filter.to_arel)
        end
      end

      class Filter
        include ActiveModel::Validations
        include FilterOperations

        def self.for(filter, **options)
          class_from_column(filter.field).new(filter, **options)
        end

        def self.class_from_column(column)
          case column.type
          when :boolean
            BooleanFilter
          when :date, :datetime
            DateFilter
          when :decimal, :integer
            NumericFilter
          when :string, :text
            StringFilter
          when :uuid
            UuidFilter
          end
        end

        def self.validate_operations(*operations)
          valid_operations = operations + [WITH]
          validates :operation, inclusion: {
            in: valid_operations,
            message: "only supports the following operations: #{valid_operations.map(&:name).join(", ")}"
          }
        end

        def self.validate_value(**options)
          validates :value, **options, unless: ->(filter) { filter.operation == WITH }
        end

        validate :validate_boolean_values, if: ->(filter) { filter.operation == WITH }

        attr_reader :table, :column, :operation, :value

        def initialize(filter, table:)
          @table = table
          @column = filter.field
          @operation = filter.operation
          @value = filter.value
        end

        def display_error_message
          return unless errors.any?
          messages = errors.messages.values.join(", ")
          "#{column.name.camelize(:lower)} (type: #{column.type}, operation: #{operation.name}, value: \"#{value}\"): #{messages}"
        end

        def to_arel
          operation.to_arel(table: table, column_name: column.name, value: value)
        end

        def validate_boolean_values
          is_valid = BOOLEAN_VALUES.any? { |v| value.casecmp(v) == 0 }
          return if is_valid
          errors.add(:value, "WITH operation only supports boolean values (#{BOOLEAN_VALUES.join(", ")})")
        end
      end

      class BooleanFilter < Filter
        validate_operations

        def to_arel
          arel = super

          if value.casecmp("f") == 0 || value.casecmp("false") == 0
            arel = arel.or(table[column.name].eq(false))
          end

          arel
        end
      end

      class DateFilter < Filter
        validate_operations GREATER_THAN, LESS_THAN
        validate :validate_iso8601

        def validate_iso8601
          is_valid = begin
            DateTime.iso8601(value)
            true
          rescue ArgumentError
            false
          end

          return if is_valid

          today = Date.today
          errors.add(:value, "only supports ISO8601 values (\"#{today.iso8601}\", \"#{today.to_datetime.iso8601}\")")
        end
      end

      class NumericFilter < Filter
        validate_operations GREATER_THAN, LESS_THAN, EQUAL, NOT_EQUAL
        validate_value numericality: { message: "only supports numerical values" }
      end

      class StringFilter < Filter
        validate_operations EQUAL, NOT_EQUAL, LIKE, NOT_LIKE
      end

      class UuidFilter < Filter
        validate_operations EQUAL, NOT_EQUAL
        validate_value format: { with: HQ::GraphQL::Util::UUID_FORMAT, message: "only supports UUID values (e.g. 00000000-0000-0000-0000-000000000000)" }
      end
    end
  end
end
