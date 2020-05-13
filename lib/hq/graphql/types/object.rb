# frozen_string_literal: true

module HQ
  module GraphQL
    module Types
      class Object < ::GraphQL::Schema::Scalar
        description "Object"

        def self.coerce_input(value, _context)
          validate_and_return_object(value)
        end

        def self.coerce_result(value, _context)
          validate_and_return_object(value)
        end

        class << self
          private

          def validate_and_return_object(value)
            if validate_object(value)
              value
            else
              raise ::GraphQL::CoercionError, "#{value.inspect} is not a valid Object"
            end
          end

          def validate_object(value)
            value.is_a?(Hash)
          end
        end
      end
    end
  end
end
