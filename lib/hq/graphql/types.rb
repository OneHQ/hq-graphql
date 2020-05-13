# frozen_string_literal: true

module HQ
  module GraphQL
    module Types
      class Error < StandardError
        MISSING_TYPE_MSG = "The GraphQL type for `%{klass}` is missing."
      end

      def self.registry
        @registry ||= Hash.new do |hash, options|
          klass, nil_klass = Array(options)
          hash[klass] = nil_klass ? nil_query_klass(klass) : klass_for(klass)
        end
      end

      def self.register(k, v)
        self[k] = v
      end

      def self.[]=(key, is_nil = false, value)
        registry[[key, is_nil]] = value
      end

      def self.[](key, is_nil = false)
        registry[[key, is_nil]]
      end

      def self.type_from_column(column)
        graphql_type =
          case column.type
          when :uuid
            ::HQ::GraphQL::Types::UUID
          when :json, :jsonb
            ::HQ::GraphQL::Types::Object
          when :integer
            ::GraphQL::Types::Int
          when :decimal
            ::GraphQL::Types::Float
          when :boolean
            ::GraphQL::Types::Boolean
          else
            ::GraphQL::Types::String
          end

        column.array ? [graphql_type] : graphql_type
      end

      # Only being used in testing
      def self.reset!
        @registry = nil
      end

      class << self
        private

        def nil_query_klass(klass_or_string)
          find_klass(klass_or_string, :nil_query_klass)
        end

        def klass_for(klass_or_string)
          find_klass(klass_or_string, :query_klass)
        end

        def find_klass(klass_or_string, method)
          klass = klass_or_string.is_a?(String) ? klass_or_string.constantize : klass_or_string
          type = find_type(klass)
          type ||= find_type(klass.base_class)
          type ||= find_type(klass.superclass)

          raise(Error, Error::MISSING_TYPE_MSG % { klass: klass.name }) if !type
          type.send(method)
        end

        def find_type(klass)
          ::HQ::GraphQL.resource_lookup(klass) || ::HQ::GraphQL.types.detect { |t| t.model_klass == klass }
        end
      end
    end
  end
end
