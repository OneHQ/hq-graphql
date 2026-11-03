# frozen_string_literal: true

require "hq/graphql/types"

module HQ
  module GraphQL
    class PaginationConnectionType < ::GraphQL::Types::Relay::BaseConnection
      field :cursors, [String], null: false
      field :total_count, Integer, null: false

      # One cursor per page across the whole list, not just the records the relation
      # is capped at. The connection's cursors are offsets past the relation's own
      # offset (see GraphQL::Pagination::RelationConnection#cursor_for), so the
      # records before it are left out.
      def cursors
        items = object.items
        count = items.is_a?(::ActiveRecord::Relation) ? [full_count - (items.offset_value || 0), 0].max : full_count

        (0...count).step(object.first || count + 1).map do |item|
          Base64.urlsafe_encode64(item.to_s).delete("=")
        end
      end

      def total_count
        full_count
      end

      private

      # Counts every record in the list, not just the ones a page can hold: root
      # queries hand over a relation already capped at limit_max (or at the
      # limit/offset arguments), so the cap is dropped before counting.
      def full_count
        @full_count ||=
          begin
            items = object.items
            if items.is_a?(::ActiveRecord::Relation)
              count = items.unscope(:limit, :offset, :order).count(:all)
              # A grouped relation counts per group
              count.is_a?(Hash) ? count.size : count
            else
              items.size
            end
          end
      end
    end
  end
end
