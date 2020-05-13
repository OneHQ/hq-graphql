# frozen_string_literal: true

module HQ
  module GraphQL
    class Field < ::GraphQL::Schema::Field
      attr_reader :authorize_action, :authorize, :klass

      def initialize(*args, authorize_action: :read, authorize: nil, klass: nil, **options, &block)
        super(*args, **options, &block)
        @authorize_action = authorize_action
        @authorize = authorize
        @klass = klass
      end

      def authorized?(object, ctx)
        super &&
          (!authorize || authorize.call(object, ctx)) &&
          ::HQ::GraphQL.authorize_field(authorize_action, self, object, ctx)
      end

      def resolve_field(object, args, ctx)
        if klass.present? && !!::GraphQL::Batch::Executor.current && object.object
          Loaders::Association.for(klass.constantize, original_name).load(object.object).then do
            super
          end
        else
          super
        end
      end
    end
  end
end
