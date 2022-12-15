# frozen_string_literal: true

require "hq/graphql/util"

module HQ
  module GraphQL
    module Types
      class UUID < ::GraphQL::Schema::Scalar
        description "UUID"

        def self.coerce_input(value, _context)
          validate_and_return_uuid(value)
        end

        def self.coerce_result(value, _context)
          validate_and_return_uuid(value)
        end

        class << self
          private

          def validate_and_return_uuid(value)
            if ::HQ::GraphQL::Util.validate_uuid(value)
              value
            else
              raise ::GraphQL::CoercionError, "#{value.inspect} is not a valid UUID"
            end
          end
        end
      end
    end
  end
end
