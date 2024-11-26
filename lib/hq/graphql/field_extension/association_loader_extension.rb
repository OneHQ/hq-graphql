# frozen_string_literal: true

require "hq/graphql/association_loader"

module HQ
  module GraphQL
    module FieldExtension
      class AssociationLoaderExtension < ::GraphQL::Schema::FieldExtension
        def resolve(object:, **_kwargs)
          restriction = _kwargs[:context][:current_user]&.restrictions&.detect do |el|
            el.restriction_operation_id == "HasHelpers::RestrictionOperation::::View" &&
            (((el.resource.name == field.original_name.camelize || el.resource.alias == field.original_name.camelize) &&
            el.resource.resource_type_id == "HasHelpers::ResourceType::::Base") ||
            ((el.resource&.parent&.name == options[:klass].name || el.resource&.parent&.alias == options[:klass].name) &&
            el.resource.field_class_name == field.original_name.camelize || el.resource.alias == field.original_name.camelize))
          end
          # return {} if restriction.present?
          AssociationLoader.for(options[:klass], field.original_name).load(object.object)
        end
      end
    end
  end
end
