# typed: false
# frozen_string_literal: true

module HQ
  module GraphQL
    module Resource
      module Mutation
        def self.build(model_name, graphql_name:, require_primary_key: false, &block)
          Class.new(::HQ::GraphQL::Mutation) do
            graphql_name graphql_name

            lazy_load do
              field :errors, ::HQ::GraphQL::Types::Object, null: false
              field :resource, ::HQ::GraphQL::Types[model_name], null: true
            end

            instance_eval(&block)

            if require_primary_key
              lazy_load do
                klass = model_name.constantize
                primary_key = klass.primary_key
                pk_column = klass.columns.detect { |c| c.name == primary_key.to_s }

                argument primary_key, ::HQ::GraphQL::Types.type_from_column(pk_column), required: true
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
