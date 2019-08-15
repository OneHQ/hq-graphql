# typed: true
# frozen_string_literal: true

module HQ
  module GraphQL
    class Mutation < ::GraphQL::Schema::Mutation
      include Scalars
      include ::HQ::GraphQL::ActiveRecordExtensions

      def self.generate_payload_type
        lazy_load!
        super
      end
    end
  end
end
