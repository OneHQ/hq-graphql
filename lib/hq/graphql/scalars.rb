require "hq/graphql/types/json"
require "hq/graphql/types/uuid"

module HQ
  module GraphQL
    module Scalars
      JSON = ::HQ::GraphQL::Types::JSON
      UUID = ::HQ::GraphQL::Types::UUID
    end
  end
end
