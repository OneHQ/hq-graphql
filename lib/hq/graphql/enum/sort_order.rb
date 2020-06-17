# frozen_string_literal: true

module HQ
  class GraphQL::Enum::SortOrder < ::HQ::GraphQL::Enum
    value "ASC", value: :asc
    value "DESC", value: :desc
  end
end
