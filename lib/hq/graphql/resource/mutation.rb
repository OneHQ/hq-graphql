# frozen_string_literal: true

module HQ
  module GraphQL
    module Resource
      module Mutation
        def self.build(model_name, action:, graphql_name:, require_primary_key: false, nil_klass: false, &block)
          Class.new(::HQ::GraphQL::Mutation) do
            graphql_name graphql_name

            define_method(:ready?) do |*args|
              super(*args) && ::HQ::GraphQL.authorized?(action, model_name, context)
            end

            lazy_load do
              field :errors, ::HQ::GraphQL::Types::Object, null: false
              field :resource, ::HQ::GraphQL::Types[model_name, nil_klass], null: true
            end

            instance_eval(&block)

            if require_primary_key
              lazy_load do
                klass = model_name.constantize
                primary_key = klass.primary_key
                argument primary_key, ::GraphQL::Types::ID, required: true
              end
            end

            def errors_from_resource(resource)
              resource.errors.to_h.deep_transform_keys { |k| k.to_s.camelize(:lower) }
            end
          end
        end
      end
    end
  end
end
