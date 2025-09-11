# frozen_string_literal: true

require "hq/graphql/ext/mutation_extensions"
require "hq/graphql/inputs"
require "hq/graphql/types"

module HQ
  module GraphQL
    module Resource
      module AutoMutation
        def build_create
          scoped_self = self

          build_mutation(action: :create) do
            define_method(:resolve) do |**args|
              resource = scoped_self.new_record(context)
              resource.assign_attributes(args[:attributes].format_nested_attributes)
              if resource.save
                {
                  resource: resource,
                  errors: {},
                }
              else
                {
                  resource: nil,
                  errors: errors_from_resource(resource)
                }
              end
            end

            lazy_load do
              argument :attributes, ::HQ::GraphQL::Inputs[scoped_self.model_name], required: true
            end
          end
        end

        def build_update
          scoped_self = self

          build_mutation(action: :update, require_primary_key: true) do
            define_method(:resolve) do |**args|
              resource = scoped_self.find_record(args, context)

              if resource
                resource.assign_attributes(args[:attributes].format_nested_attributes)
                scoped_self.after_assign_attributes(resource, args[:attributes], context) if scoped_self&.respond_to?(:after_assign_attributes)
                if resource.save
                  {
                    resource: resource,
                    errors: {},
                  }
                else
                  {
                    resource: nil,
                    errors: errors_from_resource(resource)
                  }
                end
              else
                {
                  resource: nil,
                  errors: { resource: "Unable to find #{self.class.graphql_name}" }
                }
              end
            end

            lazy_load do
              argument :attributes, ::HQ::GraphQL::Inputs[scoped_self.model_name], required: true
            end
          end
        end

        def build_copy
          scoped_self = self

          build_mutation(action: :copy, require_primary_key: true, nil_klass: true) do
            define_method(:resolve) do |**args|
              resource = scoped_self.find_record(args, context)

              if resource
                copy = resource.copy
                if copy.save
                  {
                    resource: copy,
                    errors: {},
                  }
                else
                  {
                    resource: copy,
                    errors: errors_from_resource(copy)
                  }
                end
              else
                {
                  resource: nil,
                  errors: { resource: "Unable to find #{self.class.graphql_name}" }
                }
              end
            end
          end
        end

        def build_destroy
          scoped_self = self

          build_mutation(action: :destroy, require_primary_key: true) do
            define_method(:resolve) do |**attrs|
              resource = scoped_self.find_record(attrs, context)

              if resource
                if resource.destroy
                  {
                    resource: resource,
                    errors: {},
                  }
                else
                  {
                    resource: nil,
                    errors: errors_from_resource(resource)
                  }
                end
              else
                {
                  resource: nil,
                  errors: { resource: "Unable to find #{self.class.graphql_name}" }
                }
              end
            end
          end
        end

        def build_mutation(action:, require_primary_key: false, nil_klass: false, &block)
          gql_name = "#{graphql_name}#{action.to_s.titleize}"
          scoped_model_name = model_name
          scoped_self = self

          klass = Class.new(::GraphQL::Schema::Mutation) do
            graphql_name gql_name

            define_method(:ready?) do |**args|
              super(**args) && ::HQ::GraphQL.authorized?(action, scoped_model_name, context, args)
            end

            lazy_load do
              field :errors, ::GraphQL::Types::JSON, null: false
              field :resource, ::HQ::GraphQL::Types[scoped_model_name, nil_klass], null: true
            end

            instance_eval(&block)

            if require_primary_key
              lazy_load do
                klass = scoped_model_name.constantize
                primary_key = klass.primary_key
                argument primary_key, ::GraphQL::Types::ID, required: true
              end
            end

            def errors_from_resource(resource)
              resource.errors.to_h.deep_transform_keys { |k| k.to_s.camelize(:lower) }
            end
          end

          const_set(gql_name, klass)
        end
      end
    end
  end
end
