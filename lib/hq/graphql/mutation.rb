module HQ
  module GraphQL
    class Mutation < ::GraphQL::Schema::Mutation
      include ::HQ::GraphQL::InputExtensions

      def self.generate_payload_type
        lazy_load!
        super
      end

    end
  end
end
