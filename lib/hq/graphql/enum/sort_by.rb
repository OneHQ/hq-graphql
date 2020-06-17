# frozen_string_literal: true

module HQ
  class GraphQL::Enum::SortBy < ::HQ::GraphQL::Enum
    value "CreatedAt", value: :created_at
    value "UpdatedAt", value: :updated_at
  end
end
