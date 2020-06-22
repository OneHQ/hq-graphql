# frozen_string_literal: true

module HQ
  module GraphQL
    class Field < ::GraphQL::Schema::Field
      attr_reader :authorize_action, :authorize

      def initialize(*args, authorize_action: :read, authorize: nil, klass: nil, **options, &block)
        super(*args, **options, &block)
        @authorize_action = authorize_action
        @authorize = authorize
        @klass_or_string = klass
      end

      def scope(&block)
        if block
          @scope = block
        else
          @scope
        end
      end

      def authorized?(object, ctx)
        super &&
          (!authorize || authorize.call(object, ctx)) &&
          ::HQ::GraphQL.authorize_field(authorize_action, self, object, ctx)
      end

      def klass
        @klass ||= @klass_or_string.is_a?(String) ? @klass_or_string.constantize : @klass_or_string
      end
    end
  end
end
