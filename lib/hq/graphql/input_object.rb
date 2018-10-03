module HQ
  module GraphQL
    class InputObject < ::GraphQL::Schema::InputObject
      include ::HQ::GraphQL::InputExtensions

      def self.to_graphql
        lazy_load!
        super
      end

      def with_indifferent_access
        to_h.with_indifferent_access
      end

    end
  end
end
