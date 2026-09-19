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
              attributes = args[:attributes].format_nested_attributes
              nested_errors = ::HQ::GraphQL::NestedAuthorization.errors(scoped_self.model_klass, attributes, context)
              next { resource: nil, errors: nested_errors } if nested_errors.any?

              resource = scoped_self.new_record(context)
              resource.assign_attributes(attributes)
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
                attributes = args[:attributes].format_nested_attributes
                nested_errors = ::HQ::GraphQL::NestedAuthorization.errors(scoped_self.model_klass, attributes, context)
                next { resource: nil, errors: nested_errors } if nested_errors.any?

                resource.assign_attributes(attributes)
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

          klass = Class.new(::GraphQL::Schema::Mutation) do
            graphql_name gql_name

            # A bare `false` from `ready?` stops execution and returns null with
            # NO error -- the client gets a 200, a null payload and nothing to
            # tell "you may not do this" apart from "nothing happened", which
            # reads to a form as a successful save. graphql-ruby takes
            # `[false, early_return]` instead, so the refusal comes back in the
            # payload's own `errors`, the same shape a denied nested attribute
            # already produces.
            define_method(:ready?) do |**args|
              ready = super(**args)
              # Anything other than a plain go-ahead is already the caller's
              # answer -- a refusal, or a tuple carrying its own early return.
              return ready if ready.is_a?(::Array) || !ready
              return true if ::HQ::GraphQL.authorized?(action, scoped_model_name, context)

              message = ::HQ::GraphQL::AuthorizationMessage.for(action, scoped_model_name.constantize)
              # String key, like every other key in this payload's `errors`.
              [false, { resource: nil, errors: { "base" => [message] } }]
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
              # Rails 7 exposes validation errors through `messages`, while older versions
              # may still rely on `to_h`. Keep both paths so this remains compatible across
              # Rails versions and preserves the expected GraphQL error shape.
              errors =
                if resource.errors.respond_to?(:messages)
                  resource.errors.messages
                else
                  resource.errors.to_h
                end

              errors.deep_transform_keys { |k| k.to_s.camelize(:lower) }
            end
          end

          const_set(gql_name, klass)
        end
      end
    end
  end
end
