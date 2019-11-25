# typed: true
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

      class << self
        def compare(old_schema, new_schema, criticality: :breaking)
          level = CRITICALITY[criticality]
          raise ::ArgumentError, "Invalid criticality. Possible values are #{CRITICALITY.keys.join(", ")}" unless level

          result = ::GraphQL::SchemaComparator.compare(convert_schema_to_string(old_schema), convert_schema_to_string(new_schema))
          return nil if result.identical?

          changes = {}
          changes[:breaking] = result.breaking_changes
          if level >= CRITICALITY[:dangerous]
            changes[:dangerous] = result.dangerous_changes
          end
          if level >= CRITICALITY[:non_breaking]
            changes[:non_breaking] = result.non_breaking_changes
          end

          changes
        end

        def dump_schema_to_file(directory:, filename:, schema:)
          ::FileUtils.mkdir_p(directory)
          ::File.open(::File.join(directory, filename), "w") { |file| file.write(schema.to_definition) }
        end

        private

        def convert_schema_to_string(schema)
          schema.is_a?(::String) ? schema : schema.to_definition
        end
      end
    end
  end
end
