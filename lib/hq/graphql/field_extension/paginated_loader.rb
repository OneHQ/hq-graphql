# frozen_string_literal: true

require "hq/graphql/paginated_association_loader"

module HQ
  module GraphQL
    module FieldExtension
      class PaginatedLoader < ::GraphQL::Schema::FieldExtension
        def resolve(object:, arguments:, **_options)
          limit       = arguments[:limit]
          offset      = arguments[:offset]
          sort_by     = arguments[:sort_by]
          sort_order  = arguments[:sort_order]
          scope       = field.scope.call(**arguments.except(:limit, :offset, :sort_by, :sort_order)) if field.scope
          loader      = PaginatedAssociationLoader.for(
            klass,
            association,
            internal_association: internal_association,
            scope:                scope,
            limit:                limit,
            offset:               offset,
            sort_by:              sort_by,
            sort_order:           sort_order
          )

          restriction = _options[:context][:current_user]&.restrictions&.detect do |el|
            (el.restriction_operation_id == "HasHelpers::RestrictionOperation::::View" &&
            ((el.resource.name == field.original_name.camelize || el.resource.alias == field.original_name.camelize) &&
            el.resource.resource_type_id == "HasHelpers::ResourceType::::Base") ||
            ((el.resource&.parent&.name == options[:klass].name || el.resource&.parent&.alias == options[:klass].name) &&
            el.resource.field_class_name == field.original_name.camelize || el.resource.alias == field.original_name.camelize))
          end
          return {} if restriction.present?

          loader.load(object.object)
        end

        private

        def association
          options[:association]
        end

        def internal_association
          options[:internal_association]
        end

        def klass
          options[:klass]
        end
      end
    end
  end
end
