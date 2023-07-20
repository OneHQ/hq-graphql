# frozen_string_literal: true

require "hq/graphql/association_loader"

module HQ
  module GraphQL
    module FieldExtension
      class AssociationLoaderExtension < ::GraphQL::Schema::FieldExtension
        def resolve(object:, **_kwargs)
          restriction = _kwargs[:context][:restrictions].detect { |el|
            el.restriction_operation == HasHelpers::RestrictionOperation::VIEW &&
            (((el.resource.name == field.original_name.camelize || el.resource.alias == field.original_name.camelize) &&
            el.resource_type == HasHelpers::ResourceType::BASE_RESOURCE) ||
            ((el.resource.parent&.name == options[:klass].name || el.resource.parent&.alias == options[:klass].name) &&
            el.resource.field_class_name == field.original_name.camelize || el.resource.alias == field.original_name.camelize))
          }
          return {} if restriction.present?
          AssociationLoader.for(options[:klass], field.original_name).load(object.object)
        end
      end
    end
  end
end
