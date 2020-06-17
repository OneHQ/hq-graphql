# frozen_string_literal: true

module HQ
  module GraphQL
    class Field < ::GraphQL::Schema::Field
      attr_reader :authorize_action, :authorize

      def initialize(*args, authorize_action: :read, authorize: nil, klass: nil, **options, &block)
        super(*args, **options, &block)
        @authorize_action = authorize_action
        @authorize = authorize
        @class_name = klass
      end

      def authorized?(object, ctx)
        super &&
          (!authorize || authorize.call(object, ctx)) &&
          ::HQ::GraphQL.authorize_field(authorize_action, self, object, ctx)
      end

      def resolve_field(object, args, ctx)
        if klass.present? && !!::GraphQL::Batch::Executor.current && object.object
          loader =
            if ::HQ::GraphQL.use_experimental_associations?
              limit       = args[:limit]
              offset      = args[:offset]
              sort_by     = args[:sortBy]
              sort_order  = args[:sortOrder]

              PaginatedAssociationLoader.for(
                klass,
                original_name,
                limit: limit,
                offset: offset,
                sort_by: sort_by,
                sort_order: sort_order
              )
            else
              AssociationLoader.for(klass, original_name)
            end

          loader.load(object.object)
        else
          super
        end
      end

      def klass
        @klass ||= @class_name&.constantize
      end
    end
  end
end
