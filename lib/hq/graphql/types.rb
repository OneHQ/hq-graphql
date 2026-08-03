# frozen_string_literal: true

require "hq/graphql/types/uuid"
require "hq/graphql/types/date_type"

module HQ
  module GraphQL
    module Types
      class Error < StandardError
        MISSING_TYPE_MSG = "The GraphQL type for `%{klass}` is missing."
      end

      def self.registry
        @registry ||= Hash.new do |hash, options|
          klass, nil_klass = Array(options)
          hash[options] = nil_klass ? nil_query_object(klass) : klass_for(klass)
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

      # Returns the registered GraphQL type(s) for +klass+ and all of its STI
      # subclasses, de-duplicated.
      #
      # STI subclasses that don't declare their own resource transparently fall
      # back to an ancestor's registered type (see HQ::GraphQL.lookup_resource)
      # and are collapsed by the uniq below, so passing a base class is always
      # safe: you get one entry per distinct registered type in the hierarchy.
      #
      # Pass +exclude+ to drop specific model classes (and their own subclasses)
      # from the result — useful for keeping an STI subclass out of a union.
      #
      #   Types.subtypes(Company)                    # => [Company type, Bank type, ...]
      #   Types.subtypes(Company, exclude: [Bank])   # => [Company type, ...]
      def self.subtypes(klass_or_string, is_nil = false, exclude: [])
        klass    = constantize(klass_or_string)
        excluded = Array(exclude).map { |e| constantize(e) }

        [klass, *sti_descendants(klass)].
          reject { |k| excluded.any? { |e| k <= e } }.
          map { |k| lookup_type(k, is_nil) }.
          compact.
          uniq
      end

      def self.type_from_column(column)
        graphql_type =
          case column.type
          when :uuid
            ::HQ::GraphQL::Types::UUID
          when :json, :jsonb
            ::GraphQL::Types::JSON
          when :integer
            ::GraphQL::Types::Int
          when :decimal
            ::GraphQL::Types::Float
          when :boolean
            ::GraphQL::Types::Boolean
          when :date
            ::Types::DateType
          when :datetime
            ::GraphQL::Types::ISO8601DateTime
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

        def constantize(klass_or_string)
          klass_or_string.is_a?(String) ? klass_or_string.constantize : klass_or_string
        end

        # All STI subclasses of +klass+, recursively. Only classes that are
        # already loaded are returned (Rails' descendants contract), which is
        # exactly what we want during eager-loaded schema generation.
        def sti_descendants(klass)
          klass.respond_to?(:descendants) ? klass.descendants : []
        end

        # Registered type for a single class, or nil when it has no resource.
        def lookup_type(klass, is_nil)
          self[klass, is_nil]
        rescue Error
          nil
        end

        def nil_query_object(klass_or_string)
          find_klass(klass_or_string, :nil_query_object)
        end

        def klass_for(klass_or_string)
          find_klass(klass_or_string, :query_object)
        end

        def find_klass(klass_or_string, method)
          klass = constantize(klass_or_string)
          resource = ::HQ::GraphQL.lookup_resource(klass)

          raise(Error, Error::MISSING_TYPE_MSG % { klass: klass.name }) if !resource
          resource.send(method)
        end
      end
    end
  end
end
