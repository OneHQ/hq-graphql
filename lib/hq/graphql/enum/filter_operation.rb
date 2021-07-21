# frozen_string_literal: true

require "hq/graphql/filter_operations"

module HQ
  module GraphQL
    module Enum
      class FilterOperation < ::GraphQL::Schema::Enum
        ::HQ::GraphQL::FilterOperations::OPERATIONS.each do |filter_operation|
          value filter_operation.name, value: filter_operation
        end
      end
    end
  end
end
