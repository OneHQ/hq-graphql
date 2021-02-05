# frozen_string_literal: true

require "graphql/schema_comparator"

module HQ
  module GraphQL
    class Comparator
      # Higher values will include changes from criticalities with lower values as well.
      # For example, setting the criticality as dangerous will return dangerous and breaking changes.
      CRITICALITY = {
        breaking: 0,
        dangerous: 1,
        non_breaking: 2
      }

      def self.compare(old_schema, new_schema, criticality: :breaking)
        level = CRITICALITY[criticality]
        raise ::ArgumentError, "Invalid criticality. Possible values are #{CRITICALITY.keys.join(", ")}" unless level

        result = ::GraphQL::SchemaComparator.compare(prepare_schema(old_schema), prepare_schema(new_schema))
        return if result.identical?
        changes = {}
        changes[:breaking] = result.breaking_changes
        if level >= CRITICALITY[:dangerous]
          changes[:dangerous] = result.dangerous_changes
        end
        if level >= CRITICALITY[:non_breaking]
          changes[:non_breaking] = result.non_breaking_changes
        end
        return unless changes.values.flatten.any?

        changes
      end

      class << self
        private

        def prepare_schema(schema)
          schema = ::GraphQL::Schema.from_definition(schema) if schema.is_a?(String)
          schema.load_types!
          schema
        end
      end
    end
  end
end
