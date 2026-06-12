# frozen_string_literal: true

require "hq/graphql/types"

module HQ
  module GraphQL
    class PaginationConnectionType < ::GraphQL::Types::Relay::BaseConnection
      field :cursors, [String], null: false
      field :total_count, Integer, null: false

      def cursors
        (0...(object.items.size)).step(object.first || object.items.size + 1).map do |item|
          Base64.urlsafe_encode64(item.to_s).delete("=")
        end
      end

      def total_count
        object.items.size
      end
    end
  end
end
