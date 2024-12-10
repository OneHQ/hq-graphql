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
                errors: { "resource" => "Unauthorized action for #{self.class.graphql_name.underscore.humanize}" }
              } if is_base_restricted(scoped_self.model_name, "HasHelpers::RestrictionOperation::::Create")

              resource = scoped_self.new_record(context)
              result = attribute_restrictions_handler(scoped_self.model_name, args[:attributes], "HasHelpers::RestrictionOperation::::Create")
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
                errors: { "resource" => "Unauthorized action for #{self.class.graphql_name.underscore.humanize}" }
              } if is_base_restricted(scoped_self.model_name, "HasHelpers::RestrictionOperation::::Update")

              resource = scoped_self.find_record(args, context)

              result = attribute_restrictions_handler(scoped_self.model_name, args[:attributes], "HasHelpers::RestrictionOperation::::Update")

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
                errors: { "resource" => "Unauthorized action for #{self.class.graphql_name.underscore.humanize}" }
              } if is_base_restricted(scoped_self.model_name, "HasHelpers::RestrictionOperation::::Copy")

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
                errors: { "resource" => "Unauthorized action for #{self.class.graphql_name.underscore.humanize}" }
              } if is_base_restricted(scoped_self.model_name, "HasHelpers::RestrictionOperation::::Delete")

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
              restrictions = context[:current_user]&.restrictions&.select do |el|
                (el.resource.resource_type_id == "HasHelpers::ResourceType::::BaseResource" &&
                restriction_operations.include?(el.restriction_operation_id))
              end
              restrictions
            end

            # Return true if a restriction related to a specific BaseResource, filtered by restriction operation type exist
            # model_name is an specific resource used for filter restrictions
            # restriction_operation is a ::HasHelpers::RestrictionOperation type
            def is_base_restricted(association_name, restriction_operation)
              association_name = association_name.demodulize
              restriction = get_base_restrictions([restriction_operation])&.detect do |el|
                el.resource.name == association_name
              end
              restriction.present?
            end

            # Return all attribute restrictions related to a specific resource and also all BaseResource restrictions,
            # both filtered by restriction operation
            # association_name is an specific resource used for filter restrictions
            # restriction_operations is an array of ::HasHelpers::RestrictionOperation
            def get_attributes_restrictions(association_name, restriction_operations)
              restrictions = context[:current_user]&.restrictions&.select do |el|
                ((el.resource.parent&.name == association_name &&
                  el.resource.parent&.resource_type_id == "HasHelpers::ResourceType::::BaseResource") ||
                el.resource.resource_type_id == "HasHelpers::ResourceType::::BaseResource") &&
                restriction_operations.include?(el.restriction_operation_id)
              end

              restrictions
            end

            def get_excluded_attrs(filtered_attrs, restrictions, restriction_operation, is_root)
              restrictions.select do |r|
                selected_restriction_operation = is_root ? restriction_operation.first : (
                  filtered_attrs.key?("id") ? "HasHelpers::RestrictionOperation::::Update" : "HasHelpers::RestrictionOperation::::Create"
                )
                filtered_attrs.with_indifferent_access.key?(r[0]) && r[1] == selected_restriction_operation
              end.reject { |c| c.empty? }
            end

            # Return filtered nested attributes and a list of the restricted attributes,
            # based on restrictions
            # model_name is used to specify the model inside the restricted attributes
            # attr is the object that can have nested attributes
            # attr_restrictions are the restrictions related to the model_name
            # filtered_attrs are the initial attributes
            # restricted_attrs are the initial restricted attributes.
            def apply_restrictions_in_nested(model_name, attr, attr_restrictions, filtered_attrs, restricted_attrs)
              nested_attributes = attr.keys.select { |el| el.to_s.include?("_attributes") }
              nested_attributes.each do |el|
                nested_attr_name = el.gsub("_attributes", "").classify
                # check if restrictions of create/edit and/or assign nested resource exist
                # if restrictions exist, remove nested attribute from filtered_attrs
                # else search restricted attributes from nested attribute recursively
                filtered_attr_restrictions = attr_restrictions&.detect do |ar|
                  ar.resource.name == nested_attr_name || ar.resource.name.gsub("_id", "").classify == nested_attr_name
                end
                if filtered_attr_restrictions.present?
                  restricted_attrs[model_name.camelize(:lower)].push(nested_attr_name.camelize(:lower) => "don't have permissions to create/edit")
                  filtered_attrs = filtered_attrs.except(el)
                else
                  result = recursive_nested_restrictions(
                    nested_attr_name, filtered_attrs[el],
                    { nested_attr_name.camelize(:lower) => [] },
                    ["HasHelpers::RestrictionOperation::::Create", "HasHelpers::RestrictionOperation::::Update"]
                  )
                  filtered_attrs[el] = result[:filtered_attrs]
                  filtered_attrs = filtered_attrs.except(el) if filtered_attrs[el].blank?
                  restricted_attrs[model_name.camelize(:lower)].push(result[:restricted_attrs]) if result[:restricted_attrs].present?
                end
              end
              { filtered_attrs: filtered_attrs, restricted_attrs: restricted_attrs }
            end

            # Returns filtered mutation arguments based on restrictions and a list of filtered arguments
            # model_name is an specific resource used for filter restrictions
            # filtered_attrs are mutation's nested arguments
            # restricted_attrs list of arguments that are restricted based on restrictions
            # restriction_operation is a ::HasHelpers::RestrictionOperation type
            def recursive_nested_restrictions(model_name, filtered_attrs, restricted_attrs, restriction_operation, is_root = false)
              # gets attribute restrictions of a resource
              # if restrictions exist, add related args to restricted_attrs array and removes those args from filtered_attrs
              restrictions = get_attributes_restrictions(model_name, restriction_operation)
              restrictions = restrictions.map { |el| [el.resource.name, el.restriction_operation_id] } if !restrictions.empty?
              if restrictions.present?
                excluded_attrs = filtered_attrs.kind_of?(Array) ?
                filtered_attrs.map { |attr| get_excluded_attrs(attr, restrictions, restriction_operation, is_root) }.reject { |c| c.empty? } :
                get_excluded_attrs(filtered_attrs, restrictions, restriction_operation, is_root)

                restricted_attrs[model_name.camelize(:lower)] += excluded_attrs.map do |el|
                  { el[0].camelize(:lower) => "don't have permissions to #{el[1].demodulize.camelize(:lower)}" }
                end if excluded_attrs.present?

                filtered_attrs = filtered_attrs.kind_of?(Array) ?
                filtered_attrs.map { |el| el.with_indifferent_access.except(*restrictions.flatten) } :
                filtered_attrs.with_indifferent_access.except(*restrictions.flatten) if restrictions.present?
              end

              # if there's an association for create/update, checks the existance of related restrictions
              # if restrictions exist, add related args to restricted_attrs array and removes those args from filtered_attrs
              attr_restrictions = (
                get_base_restrictions(["HasHelpers::RestrictionOperation::::Create", "HasHelpers::RestrictionOperation::::Update"]) +
                get_attributes_restrictions(model_name, ["HasHelpers::RestrictionOperation::::Create", "HasHelpers::RestrictionOperation::::Update"])
              )
              if filtered_attrs.kind_of?(Array)
                filtered_attrs.each_with_index do |attr, idx|
                  result = apply_restrictions_in_nested(model_name, attr, attr_restrictions, filtered_attrs[idx], restricted_attrs)
                  filtered_attrs[idx] = result[:filtered_attrs]
                  restricted_attrs = result[:restricted_attrs]
                end
                filtered_attrs = filtered_attrs.reject { |c| c.blank? }
              else
                filtered_attrs, restricted_attrs = apply_restrictions_in_nested(model_name, filtered_attrs, attr_restrictions, filtered_attrs, restricted_attrs).
                values_at(:filtered_attrs, :restricted_attrs)
              end
              restricted_attrs[model_name.camelize(:lower)] = restricted_attrs[model_name.camelize(:lower)].uniq
              restricted_attrs = restricted_attrs.except(model_name.camelize(:lower)) if restricted_attrs.kind_of?(Hash) && restricted_attrs[model_name.camelize(:lower)].blank?
              { filtered_attrs: filtered_attrs, restricted_attrs: restricted_attrs }
            end

            # returns mutation args filtered by restrictions and errors warning with all args removed
            def attribute_restrictions_handler(model_name, attributes, restriction_operation)
              association_name = model_name.demodulize
              filtered_attrs = attributes.format_nested_attributes.with_indifferent_access

              filtered_attrs, restricted_attrs = recursive_nested_restrictions(
                association_name,
                filtered_attrs,
                { association_name.camelize(:lower) => [] },
                [restriction_operation], true
              ).values_at(:filtered_attrs, :restricted_attrs) if context[:current_user]&.restrictions.present?

              errors = {}
              errors = { "warning" => restricted_attrs } if restricted_attrs.present?

              { errors: errors, filtered_attrs: filtered_attrs }
            end
          end

          const_set(gql_name, klass)
        end
      end
    end
  end
end
