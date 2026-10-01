# frozen_string_literal: true

require "hq/graphql/paginated_association_loader"

module HQ
  module GraphQL
    module FieldExtension
      class PaginatedLoader < ::GraphQL::Schema::FieldExtension
        def resolve(object:, arguments:, context:, **_options)
          limit = arguments[:limit]
          offset = arguments[:offset]
          sort_by = arguments[:sort_by]
          sort_order = arguments[:sort_order]
          scope = field.scope.call(**arguments.except(:limit, :offset, :sort_by, :sort_order)) if field.scope
          loader = PaginatedAssociationLoader.for(
            klass,
            association,
            internal_association: internal_association,
            scope: scope,
            context: context,
            apply_default_scope: field.apply_default_scope?,
            filter_unauthorized_items: field.filter_unauthorized_items?,
            authorize_action: field.authorize_action,
            limit: limit,
            offset: offset,
            sort_by: sort_by,
            sort_order: sort_order
          )

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
