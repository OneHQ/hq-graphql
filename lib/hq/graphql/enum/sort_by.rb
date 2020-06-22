# frozen_string_literal: true

require "hq/graphql/enum"

module HQ
  class GraphQL::Enum::SortBy < ::HQ::GraphQL::Enum
    value "CreatedAt", value: :created_at
    value "UpdatedAt", value: :updated_at
  end
end
