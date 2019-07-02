module HQ
  module GraphQL
    module Types
      class Error < StandardError
        MISSING_TYPE_MSG = "The GraphQL type for `%{klass}` is missing.".freeze
      end

      def self.[](key)
        @types ||= Hash.new do |hash, klass|
          hash[klass] = klass_for(klass)
        end
        @types[key]
      end

      def self.type_from_column(column)
        case column&.cast_type&.type
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
      end

      # Only being used in testing
      def self.reset!
        @types = nil
      end

      class << self
        private

        def klass_for(klass_or_string)
          klass = klass_or_string.is_a?(String) ? klass_or_string.constantize : klass_or_string
          ::HQ::GraphQL.types.detect { |t| t.model_klass == klass }&.query_klass ||
          ::HQ::GraphQL.types.detect { |t| t.model_klass == klass.base_class }&.query_klass ||
             raise(Error, Error::MISSING_TYPE_MSG % { klass: klass.name })
        end
      end

    end
  end
end
