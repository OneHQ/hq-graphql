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
              return {
                resource: nil,
                errors: { resource: "Unauthorized action for #{self.class.graphql_name}" }
              } if is_base_restricted(scoped_self.model_name, HasHelpers::RestrictionOperation::CREATE)

              resource = scoped_self.new_record(context)
              result = attribute_restrictions_handler(scoped_self.model_name, args[:attributes], HasHelpers::RestrictionOperation::CREATE)
              resource.assign_attributes(result[:filtered_attrs])
              if resource.save
                {
                  resource: resource,
                  errors: result[:errors],
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
              return {
                resource: nil,
                errors: { resource: "Unauthorized action for #{self.class.graphql_name}" }
              } if is_base_restricted(scoped_self.model_name, HasHelpers::RestrictionOperation::UPDATE)

              resource = scoped_self.find_record(args, context)

              result = attribute_restrictions_handler(scoped_self.model_name, args[:attributes], HasHelpers::RestrictionOperation::UPDATE)

              if resource
                resource.assign_attributes(result[:filtered_attrs])
                if resource.save
                  {
                    resource: resource,
                    errors: result[:errors],
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
              return {
                resource: nil,
                errors: { resource: "Unauthorized action for #{self.class.graphql_name}" }
              } if is_base_restricted(scoped_self.model_name, HasHelpers::RestrictionOperation::COPY)

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
              return {
                resource: nil,
                errors: { resource: "Unauthorized action for #{self.class.graphql_name}" }
              } if is_base_restricted(scoped_self.model_name, HasHelpers::RestrictionOperation::DELETE)

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

            define_method(:ready?) do |**args|
              super(**args) && ::HQ::GraphQL.authorized?(action, scoped_model_name, context)
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

            def get_base_restrictions(restriction_operation)
              restrictions = context[:restrictions].select { |el|
                (el.resource.resource_type == HasHelpers::ResourceType::BASE_RESOURCE &&
                el.restriction_operation == restriction_operation)
              }
              restrictions
            end


            def is_base_restricted(model_name, restriction_operation)
              association_name = model_name.demodulize
              restriction = get_base_restrictions(restriction_operation).detect { |el|
                el.resource.name == association_name || el.resource.alias == association_name
              }
              restriction.present?
            end


            def get_attributes_restrictions(model_name, restriction_operation)
              association_name = model_name.demodulize
              restrictions = context[:restrictions].select { |el|
                (el.resource.parent&.name != association_name && el.resource.parent&.alias != association_name && el.resource.parent&.resource_type == HasHelpers::ResourceType::BASE_RESOURCE) &&
                el.restriction_operation == restriction_operation
              }

              restrictions
            end

            def recursive_nested_restrictions(formatted_attrs, aux_restricted, restriction_operation)
              byebug
              nested_attributes = formatted_attrs.keys.select { |el| el.to_s.include?("_attributes") }
              nested_attributes.each{ |el|
                nested_attr_name = el.to_s.gsub("_attributes","").classify
                nested_attr_restrictions = context[:restrictions].detect { |el|
                  (el.resource.name == nested_attr_name || el.resource.alias == nested_attr_name) &&
                    el.resource.resource_type == HasHelpers::ResourceType::BASE_RESOURCE &&
                  [HasHelpers::RestrictionOperation::CREATE, HasHelpers::RestrictionOperation::UPDATE].include?(el.restriction_operation)
                }
                if(!nested_attr_restrictions.blank?)
                  aux_restricted.push([el]) if !nested_attr_restrictions.nil?
                  formatted_attrs = formatted_attrs.with_indifferent_access.except(el)
                end

                if(nested_attr_restrictions.blank?)
                  nested_attr_restrictions_two = context[:restrictions].select { |el|
                    (el.resource.parent&.name == nested_attr_name || el.resource.parent&.alias == nested_attr_name &&
                      el.resource.parent&.resource_type == HasHelpers::ResourceType::BASE_RESOURCE) &&
                    el.restriction_operation == restriction_operation
                  }

                  nested_attr_restrictions_two = nested_attr_restrictions_two.map{ |el| [el.resource.name, el.resource.alias] }.flatten if !nested_attr_restrictions_two.empty?
                  restricted_nested_params = formatted_attrs[el].kind_of?(Array) ?
                  formatted_attrs[el].map{ |attr| attr.with_indifferent_access.keys.select { |el| nested_attr_restrictions_two.include?(el) }}.flatten :
                  formatted_attrs[el].with_indifferent_access.keys.select { |el| nested_attr_restrictions_two.include?(el) }


                  aux_restricted.push([el, restricted_nested_params]) if !restricted_nested_params.empty?
                  formatted_attrs[el] = formatted_attrs[el].kind_of?(Array) ?
                  formatted_attrs[el].map{ |el| el.with_indifferent_access.except(*restricted_nested_params) } :
                  formatted_attrs[el].with_indifferent_access.except(*restricted_nested_params) if !restricted_nested_params.blank?

                  if(formatted_attrs[el].kind_of?(Array))
                    formatted_attrs[el].each_with_index{ |attr,idx|
                       nested = formatted_attrs[el][idx].select { |el| el.to_s.include?("_attributes") }
                       aux_result = {}
                       aux_result = recursive_nested_restrictions(nested, [], restriction_operation) if !nested.empty?
                       formatted_attrs[el][idx] = aux_result[:formatted_attrs]
                       aux_restricted.push(aux_result[:aux_restricted])
                    }
                  else
                    nested = formatted_attrs[el].keys.select { |el| el.to_s.include?("_attributes") }
                    aux_result = {}
                    aux_result = recursive_nested_restrictions(nested, [], restriction_operation) if !nested.empty?
                    formatted_attrs[el] = aux_result[:formatted_attrs]
                    aux_restricted.push(aux_result[:aux_restricted])
                  end
                end
              }
              return { formatted_attrs: formatted_attrs, aux_restricted: aux_restricted }
            end

            def attribute_restrictions_handler(model_name, attributes, restriction_operation)
              association_name = model_name.demodulize
              formatted_attrs = attributes.format_nested_attributes
              restrictions = get_attributes_restrictions(model_name, restriction_operation)

              restrictions = restrictions.map{ |el| [el.resource.name, el.resource.alias] }.flatten if !restrictions.empty?
              filtered_attrs = formatted_attrs.with_indifferent_access.except(*restrictions)
              restricted_keys = formatted_attrs.with_indifferent_access.keys.select { |el| restrictions.include?(el) }

              prueba = recursive_nested_restrictions(formatted_attrs, [], restriction_operation)
byebug
              errors = {}

              errors = { warning: "Unauthorized for update the following attributes: #{restricted_keys.join(', ')}"} if !restricted_keys.empty?

              { errors: errors, filtered_attrs: filtered_attrs }
            end
          end

          const_set(gql_name, klass)
        end
      end
    end
  end
end
