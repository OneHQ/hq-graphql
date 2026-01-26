# frozen_string_literal: true

require "hq/graphql/ext/enum_extensions"

module HQ
  module GraphQL
    module Enum
      class SortOrder < ::GraphQL::Schema::Enum
        value "ASC",  value: :asc
        value "DESC", value: :desc
      end
    end
  end
end
