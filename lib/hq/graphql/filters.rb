# frozen_string_literal: true
require "hq/graphql/filter_operations"
require "hq/graphql/util"
require "hq/graphql/filters/relative_date_expression"

module HQ
  module GraphQL
    class Filters
      BOOLEAN_VALUES = ["t", "f", "true", "false"]
      BOOLEAN_FILTER_OPERATIONS = [FilterOperations::WITH].freeze
      DATE_FILTER_OPERATIONS = [
        FilterOperations::GREATER_THAN,
        FilterOperations::LESS_THAN,
        FilterOperations::EQUAL,
        FilterOperations::NOT_EQUAL,
        FilterOperations::DATE_RANGE_BETWEEN,
        FilterOperations::DATE_RANGE_NOT_BETWEEN
      ].freeze
      DATE_FILTER_OPERATION_NAMES = DATE_FILTER_OPERATIONS.map { |operation| operation.name.to_sym }.freeze
      NUMERIC_FILTER_OPERATIONS = [
        FilterOperations::GREATER_THAN,
        FilterOperations::LESS_THAN,
        FilterOperations::EQUAL,
        FilterOperations::NOT_EQUAL,
        FilterOperations::IN
      ].freeze
      NUMERIC_FILTER_OPERATION_NAMES = NUMERIC_FILTER_OPERATIONS.map { |operation| operation.name.to_sym }.freeze
      STRING_FILTER_OPERATIONS = [
        FilterOperations::EQUAL,
        FilterOperations::NOT_EQUAL,
        FilterOperations::LIKE,
        FilterOperations::NOT_LIKE,
        FilterOperations::IN
      ].freeze
      STRING_FILTER_OPERATION_NAMES = STRING_FILTER_OPERATIONS.map { |operation| operation.name.to_sym }.freeze
      UUID_FILTER_OPERATIONS = [
        FilterOperations::EQUAL,
        FilterOperations::NOT_EQUAL,
        FilterOperations::IN
      ].freeze
      UUID_FILTER_OPERATION_NAMES = UUID_FILTER_OPERATIONS.map { |operation| operation.name.to_sym }.freeze

      def self.supported?(column)
        !!Filter.class_from_column(column)
      end

      def self.apply_date_filter(scope, column:, operation:, date_value:, date_range_value:)
        column = normalize_column(scope, column)
        condition = date_filter_condition(column: column, operation: operation, date_value: date_value, date_range_value: date_range_value)
        scope.where(condition)
      end

      def self.date_filter_condition(column:, operation:, date_value:, date_range_value:)
        operation_obj = resolve_operation(operation)
        unless DATE_FILTER_OPERATIONS.include?(operation_obj)
          raise ArgumentError, "Unsupported date filter operation #{operation}"
        end

        case operation_obj
        when FilterOperations::DATE_RANGE_BETWEEN
          from, to = RelativeDateExpression.parse_range(date_range_value)
          column.between(from..to)
        when FilterOperations::DATE_RANGE_NOT_BETWEEN
          from, to = RelativeDateExpression.parse_range(date_range_value)
          column.lt(from).or(column.gt(to))
        else
          value = RelativeDateExpression.parse_boundary(date_value)
          operation_obj.to_arel(
            table: column.relation,
            column_name: column.name,
            value: value,
            array_values: nil,
            column_value: nil
          )
        end
      end

      def self.apply_basic_filter(scope, column:, operation:, value: nil, array_values: nil, column_value: nil)
        column = normalize_column(scope, column)
        condition = condition_for_operation(column: column, operation: operation, value: value, array_values: array_values, column_value: column_value)
        scope.where(condition)
      end

      class << self
        alias apply_numeric_filter apply_basic_filter
        alias apply_string_filter apply_basic_filter
        alias apply_uuid_filter apply_basic_filter
      end

      def self.apply_boolean_filter(scope, column:, value:, operation: FilterOperations::WITH)
        column = normalize_column(scope, column)
        condition = boolean_condition(column: column, value: value, operation: operation)
        scope.where(condition)
      end

      def self.boolean_condition(column:, value:, operation: FilterOperations::WITH)
        condition = condition_for_operation(column: column, operation: operation, value: value, array_values: nil, column_value: nil)
        if value.present? && (value.casecmp("f") == 0 || value.casecmp("false") == 0)
          condition = condition.or(column.eq(false))
        end
        condition
      end

      def self.condition_for_operation(column:, operation:, value:, array_values:, column_value:)
        operation_obj = resolve_operation(operation)
        operation_obj.to_arel(
          table: column.relation,
          column_name: column.name,
          value: value,
          array_values: array_values,
          column_value: column_value
        )
      end

      def self.normalize_column(scope, column)
        return column if column.is_a?(Arel::Attributes::Attribute)
        return column if column.respond_to?(:relation) && column.respond_to?(:name)

        arel_table = if scope.respond_to?(:arel_table)
          scope.arel_table
        elsif scope.respond_to?(:klass)
          scope.klass.arel_table
        else
          raise ArgumentError, "Cannot determine table for provided scope"
        end

        arel_table[column.to_sym]
      end

      def self.resolve_operation(operation)
        return operation if operation.is_a?(FilterOperations::Operation)
        FilterOperations::OPERATIONS.find { |op| op.name == operation.to_s } or
          raise ArgumentError, "Unsupported filter operation #{operation}"
      end

      class FieldDefinition
        attr_reader :name, :type, :description

        def initialize(name:, type:, graphql_name: nil, description: nil, operations: nil, resolver: nil)
          @name = name.to_s
          @graphql_name = graphql_name || @name.camelize(:lower)
          @type = type
          @description = description
          @resolver = resolver
          @operations = normalize_operations(Array(operations))
        end

        def graphql_name
          @graphql_name
        end

        def resolver?
          @resolver.present?
        end

        def allowed_operations
          @operations
        end

        def apply(scope:, table:, model:, operation:, value:, array_values:, column_value:, date_value:, date_range_value:, filter:)
          return unless resolver?
          @resolver.call(
            scope,
            operation: operation,
            value: value,
            array_values: array_values,
            column_value: column_value,
            date_value: date_value,
            date_range_value: date_range_value,
            table: table,
            model: model,
            filter: filter
          )
        end

        private

        def normalize_operations(operations)
          filtered = operations.compact
          return if filtered.empty?

          filtered.map do |operation|
            next operation if operation.is_a?(::HQ::GraphQL::FilterOperations::Operation)

            ::HQ::GraphQL::FilterOperations::OPERATIONS.find do |defined_operation|
              defined_operation.name == operation.to_s
            end or raise ArgumentError, "Unknown filter operation: #{operation}"
          end
        end
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
        filters.reduce(model.all) do |scope, filter|
          filter_scope = filter.to_relation(model)
          next scope unless filter_scope
          filter.is_or ? scope.or(filter_scope) : scope.merge(filter_scope)
        end
      end

      class Filter
        include ActiveModel::Validations
        include FilterOperations

        def self.for(filter, **options)
          class_from_column(filter.field).new(filter, **options)
        end

        def self.class_from_column(column)
          return unless column
          column_type = column.type
          case column_type
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
          validates :value, **options, unless: ->(filter) { filter.operation == WITH || filter.operation == IN || column_value.present? }
        end

        validate :validate_boolean_values, if: ->(filter) { filter.operation == WITH }

        validate :value_presence, if: ->(filter) { filter.operation != IN && filter.operation != EQUAL && filter.operation != NOT_EQUAL }
        validate :array_values_presence, if: ->(filter) { filter.operation == IN }
        validate :column_value_presence, if: ->(filter) { filter.operation == EQUAL || filter.operation == NOT_EQUAL }

        attr_reader :table, :column, :operation, :is_or, :value, :array_values, :column_value, :date_value, :date_range_value

        def initialize(filter, table:)
          @table = table
          @column = filter.field
          @operation = filter.operation
          @is_or = filter.is_or
          @value = filter.value
          @array_values = filter.array_values
          @column_value = filter.column_value
          @date_value = normalize_input(filter.respond_to?(:date_value) ? filter.date_value : nil)
          @date_range_value = normalize_input(filter.respond_to?(:date_range_value) ? filter.date_range_value : nil)
        end

        validate :validate_field_operations

        def display_error_message
          return unless errors.any?
          messages = errors.messages.values.join(", ")
          "#{filter_name} (type: #{column.type}, operation: #{operation.name}, value: \"#{display_value}\"): #{messages}"
        end

        def to_arel
          column_attribute = table[column.name]
          Filters.condition_for_operation(
            column: column_attribute,
            operation: operation,
            value: value,
            array_values: array_values,
            column_value: column_value
          )
        end

        def to_relation(model)
          if custom_field?
            column.apply(
              scope: model.all,
              table: table,
              model: model,
              operation: operation,
              value: value,
              array_values: array_values,
              column_value: column_value,
              date_value: date_value,
              date_range_value: date_range_value,
              filter: self
            )
          else
            model.all.where(to_arel)
          end
        end

        def validate_boolean_values
          is_valid = BOOLEAN_VALUES.any? { |v| value.casecmp(v) == 0 }
          return if is_valid
          errors.add(:value, "WITH operation only supports boolean values (#{BOOLEAN_VALUES.join(", ")})")
        end

        def value_presence
          return unless value.nil?
          errors.add(:value, "value can't be null")
        end

        def array_values_presence
          return unless array_values.nil?
          errors.add(:array_values, "array values can't be null")
        end

        def column_value_presence
          return unless value.nil? && column_value.nil?
          errors.add(:array_values, "value or column value must be provided")
        end

        private

        def filter_name
          if column.respond_to?(:graphql_name)
            column.graphql_name
          else
            column.name.camelize(:lower)
          end
        end

        def normalize_input(value)
          return if value.nil?

          case value
          when Hash
            value.deep_symbolize_keys
          when ::GraphQL::Schema::InputObject
            value.to_h.each_with_object({}) do |(key, val), memo|
              memo[key.to_sym] = normalize_input(val)
            end
          else
            value
          end
        end

        def display_value
          value || array_values || column_value || date_value || date_range_value
        end

        def custom_field?
          column.is_a?(FieldDefinition) && column.resolver?
        end

        def validate_field_operations
          return unless column.respond_to?(:allowed_operations)
          allowed_operations = column.allowed_operations
          return if allowed_operations.blank?

          return if allowed_operations.any? { |allowed| allowed.name == operation.name }

          messages = allowed_operations.map(&:name).join(", ")
          errors.add(:operation, "only supports the following operations: #{messages}")
        end
      end

      class BooleanFilter < Filter
        validate_operations(*BOOLEAN_FILTER_OPERATIONS)

        def to_arel
          column_attribute = table[column.name]
          Filters.boolean_condition(column: column_attribute, value: value, operation: operation)
        end
      end

      class DateFilter < Filter
        validate_operations(*DATE_FILTER_OPERATIONS)
        validate :validate_date_expression

        def to_arel
          if column_value.present?
            return operation.to_arel(table: table, column_name: column.name, value: value, array_values: array_values, column_value: column_value)
          end

          column_attribute = table[column.name]
          Filters.date_filter_condition(
            column: column_attribute,
            operation: operation,
            date_value: expression_source,
            date_range_value: range_expression_source
          )
        end

        private

        def expression_source
          date_value.presence || value
        end

        def range_expression_source
          date_range_value.presence || value
        end

        def validate_date_expression
          return if column_value.present?

          if range_operation?
            RelativeDateExpression.parse_range(range_expression_source)
          else
            RelativeDateExpression.parse_boundary(expression_source)
          end
        rescue ArgumentError => e
          errors.add(:value, e.message)
        end

        def value_presence
          return if column_value.present?

          if range_operation?
            if range_expression_source.blank?
              errors.add(:value, "dateRangeValue must be provided for this operation")
            end
          elsif expression_source.blank?
            errors.add(:value, "value or dateValue must be provided for this operation")
          end
        end

        def column_value_presence
          return unless [EQUAL, NOT_EQUAL].include?(operation)
          return if column_value.present?
          return if expression_source.present?

          errors.add(:value, "value, dateValue, or columnValue must be provided")
        end

        def range_operation?
          [DATE_RANGE_BETWEEN, DATE_RANGE_NOT_BETWEEN].include?(operation)
        end

      end

      class NumericFilter < Filter
        validate_operations(*NUMERIC_FILTER_OPERATIONS)
        validate_value numericality: { message: "only supports numerical values" }
      end

      class StringFilter < Filter
        validate_operations(*STRING_FILTER_OPERATIONS)
      end

      class UuidFilter < Filter
        validate_operations(*UUID_FILTER_OPERATIONS)
        validate_value format: { with: HQ::GraphQL::Util::UUID_FORMAT, message: "only supports UUID values (e.g. 00000000-0000-0000-0000-000000000000)" }
      end
    end
  end
end
