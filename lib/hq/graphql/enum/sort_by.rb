# frozen_string_literal: true

require "hq/graphql/ext/enum_extensions"

module HQ
  module GraphQL
    module Enum
      class SortBy < ::GraphQL::Schema::Enum
        value "CreatedAt", value: :created_at
        value "UpdatedAt", value: :updated_at
      end
    end
  end
end
