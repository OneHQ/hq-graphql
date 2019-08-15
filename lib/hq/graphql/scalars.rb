# frozen_string_literal: true

require "hq/graphql/types/object"
require "hq/graphql/types/uuid"

module HQ
  module GraphQL
    module Scalars
      Object = ::HQ::GraphQL::Types::Object
      UUID = ::HQ::GraphQL::Types::UUID
    end
  end
end
