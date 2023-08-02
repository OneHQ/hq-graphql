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

            # return all restrictions related to a resource of type BaseResource, filtered by restriction operation type
            # restriction_operations is an array of ::HasHelpers::RestrictionOperation
            def get_base_restrictions(restriction_operations)
              restrictions = context[:restrictions].select { |el|
                (el.resource.resource_type == HasHelpers::ResourceType::BASE_RESOURCE &&
                restriction_operations.include?(el.restriction_operation))
              }
              restrictions
            end

            # Return true if a restriction related to a specific BaseResource, filtered by restriction operation type exist
            # model_name is an specific resource used for filter restrictions
            # restriction_operation is a ::HasHelpers::RestrictionOperation type
            def is_base_restricted(association_name, restriction_operation)
              association_name = association_name.demodulize
              restriction = get_base_restrictions([restriction_operation]).detect { |el|
                el.resource.name == association_name
              }
              restriction.present?
            end

            # Return all attribute restriction related to a specific resource and also all BaseResource restrictions,
            # both filtered by restriction operation
            # association_name is an specific resource used for filter restrictions
            # restriction_operations is an array of ::HasHelpers::RestrictionOperation
            def get_attributes_restrictions(association_name, restriction_operations)
              restrictions = context[:restrictions].select { |el|
                ((el.resource.parent&.name == association_name &&
                  el.resource.parent&.resource_type == HasHelpers::ResourceType::BASE_RESOURCE) ||
                el.resource.resource_type == HasHelpers::ResourceType::BASE_RESOURCE) &&
                restriction_operations.include?(el.restriction_operation)
              }

              restrictions
            end

            # Returns filtered mutation arguments based on restrictions and a list of filtered arguments
            # model_name is an specific resource used for filter restrictions
            # formatted_args are mutation's nested arguments
            # restricted_args list of arguments that are restricted based on restrictions
            # restriction_operation is a ::HasHelpers::RestrictionOperation type
            def recursive_nested_restrictions(model_name, formatted_args, restricted_args, restriction_operation)
              # gets attribute restrictions of a resource
              # if restrictions exist, add related args to restricted_args array and removes those args from formatted_args
              restrictions = get_attributes_restrictions(model_name, restriction_operation)
              restrictions = restrictions.map{ |el| [el.resource.name, el.restriction_operation.id] } if !restrictions.empty?
              if(!restrictions.blank?)
                excluded_attrs = formatted_args.kind_of?(Array) ?
                formatted_args.map{ |attr|
                  restrictions.select {
                    |r| attr.with_indifferent_access.keys.include?(r[0]) && r[1] ==  (attr.key?("id") ? HasHelpers::RestrictionOperation::UPDATE.id : HasHelpers::RestrictionOperation::CREATE.id)
                  }
                }.reject { |c| c.empty? } :
                restrictions.select { |r|
                  formatted_args.with_indifferent_access.keys.include?(r[0]) && r[1] ==  (formatted_args.key?("id") ? HasHelpers::RestrictionOperation::UPDATE.id : HasHelpers::RestrictionOperation::CREATE.id)
                }.reject { |c| c.empty? }
                restricted_args[model_name.camelize(:lower)] += excluded_attrs.map { |el| {el[0].camelize(:lower) => "don't have permissions to #{el[1].demodulize.camelize(:lower)}"}} if !excluded_attrs.blank?
                formatted_args = formatted_args.kind_of?(Array) ?
                formatted_args.map{ |el|
                  el.with_indifferent_access.except(*restrictions.flatten)
                } :
                formatted_args.with_indifferent_access.except(*restrictions.flatten) if !restrictions.blank?
              end

              # if there's an association for create/update, checks the existance of related restrictions
              # if restrictions exist, add related args to restricted_args array and removes those args from formatted_args
              if(formatted_args.kind_of?(Array))
                formatted_args.each_with_index{ |attr, idx|
                  nested_attributes = attr.keys.select { |el| el.to_s.include?("_attributes") }
                  nested_attributes.each{ |el|
                    nested_attr_name = el.gsub("_attributes","").classify
                    attr_restrictions = get_base_restrictions(
                      [HasHelpers::RestrictionOperation::CREATE, HasHelpers::RestrictionOperation::UPDATE]).detect { |el| el.resource.name == nested_attr_name }
                    if(!attr_restrictions.blank?)
                      restricted_args[model_name.camelize(:lower)].push(nested_attr_name.camelize(:lower) => "don't have permissions to create/edit") if !attr_restrictions.nil?
                      formatted_args[idx] = formatted_args[idx].except(el)
                    else
                      result = recursive_nested_restrictions(nested_attr_name, formatted_args[idx][el], {nested_attr_name.camelize(:lower) => []}, [HasHelpers::RestrictionOperation::CREATE, HasHelpers::RestrictionOperation::UPDATE])
                      formatted_args[idx][el] = result[:formatted_args]
                      restricted_args[model_name.camelize(:lower)].push(result[:restricted_args]) if !result[:restricted_args].blank?
                    end
                  }
                }
                formatted_args = formatted_args.reject { |c| c.blank? }
              else
                nested_attributes = formatted_args.keys.select { |el| el.to_s.include?("_attributes") }
                nested_attributes.each{ |el|
                  nested_attr_name = el.gsub("_attributes","").classify
                  attr_restrictions = get_base_restrictions(
                    [HasHelpers::RestrictionOperation::CREATE, HasHelpers::RestrictionOperation::UPDATE]).detect { |el| el.resource.name == nested_attr_name }
                  if(!attr_restrictions.blank?)
                    restricted_args[model_name.camelize(:lower)].push(nested_attr_name.camelize(:lower) => "don't have permissions to create/edit") if !attr_restrictions.nil?
                    formatted_args = formatted_args.except(el)
                  else
                    result = recursive_nested_restrictions(nested_attr_name, formatted_args[el], {nested_attr_name.camelize(:lower) => []}, [HasHelpers::RestrictionOperation::CREATE, HasHelpers::RestrictionOperation::UPDATE])
                    if(result[:formatted_args].blank?)
                      formatted_args = formatted_args.except(el)
                    else
                      formatted_args[el] = result[:formatted_args]
                    end
                    restricted_args[model_name.camelize(:lower)].push(result[:restricted_args]) if !result[:restricted_args].blank?
                  end
                }
              end
              return { formatted_args: formatted_args, restricted_args: restricted_args }
            end

            # returns mutation args filtered by restrictions and errors warning with all args removed
            def attribute_restrictions_handler(model_name, attributes, restriction_operation)
              association_name = model_name.demodulize
              formatted_args = attributes.format_nested_attributes.with_indifferent_access
              # restrictions = get_attributes_restrictions(association_name, [restriction_operation])
              #
              # restrictions = restrictions.map{ |el| [el.resource.name, el.resource.alias] }.flatten if !restrictions.empty?
              # filtered_attrs = formatted_args.with_indifferent_access.except(*restrictions)
              # restricted_keys = formatted_args.with_indifferent_access.keys.select { |el| restrictions.include?(el) }

              prueba = recursive_nested_restrictions(association_name, formatted_args, {association_name.camelize(:lower) => []}, [restriction_operation])
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
