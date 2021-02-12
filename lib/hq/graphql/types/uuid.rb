# frozen_string_literal: true

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
            if validate_uuid(value)
              value
            else
              raise ::GraphQL::CoercionError, "#{value.inspect} is not a valid UUID"
            end
          end

          def validate_uuid(value)
            !value || !!value.to_s.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
          end
        end
      end
    end
  end
end
