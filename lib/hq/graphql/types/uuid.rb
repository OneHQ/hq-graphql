# typed: strict
# frozen_string_literal: true

module HQ
  module GraphQL
    module Types
      class UUID < ::GraphQL::Schema::Scalar
        description "UUID"

        class << self
          extend T::Sig

          sig { params(value: T.untyped, _context: T.untyped).returns(String) }
          def coerce_input(value, _context)
            validate_and_return_uuid(value)
          end

          sig { params(value: T.untyped, _context: T.untyped).returns(String) }
          def coerce_result(value, _context)
            validate_and_return_uuid(value)
          end

          private

          sig { params(value: T.untyped).returns(String) }
          def validate_and_return_uuid(value)
            if validate_uuid(value)
              value
            else
              raise ::GraphQL::CoercionError, "#{value.inspect} is not a valid UUID"
            end
          end

          sig { params(value: T.untyped).returns(T::Boolean) }
          def validate_uuid(value)
            !!value.to_s.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
          end
        end
      end
    end
  end
end
