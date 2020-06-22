# frozen_string_literal: true

require "hq/graphql/enum"

module HQ
  class GraphQL::Enum::SortOrder < ::HQ::GraphQL::Enum
    value "ASC", value: :asc
    value "DESC", value: :desc
  end
end
