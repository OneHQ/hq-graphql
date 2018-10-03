require "hq/graphql/scalars"

module HQ
  module GraphQL
    module Types

      def self.[](key)
        @schema_objects ||= Hash.new do |hash, klass|
          hash[klass] = klass_for(klass)
        end
        @schema_objects[key]
      end

      def self.type_from_column(column)
        case column&.cast_type&.type
        when :uuid
          ::HQ::GraphQL::Types::UUID
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
        @schema_objects = nil
      end

      class << self
        private

        def klass_for(klass)
          hql_klass_name = ::HQ::GraphQL.graphql_type_from_model(klass)
          hql_klass = hql_klass_name.safe_constantize
          return hql_klass if hql_klass

          module_name = hql_klass_name.deconstantize.presence
          hql_module = module_name ? (module_name.safe_constantize || ::Object.const_set(module_name, Module.new)) : ::Object

          hql_klass = Class.new(::HQ::GraphQL::Object) do
            with_model klass.name
          end

          hql_module.const_set(hql_klass_name.demodulize, hql_klass)
        end
      end

    end
  end
end
