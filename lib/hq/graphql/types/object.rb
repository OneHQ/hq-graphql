module HQ
  module GraphQL
    module Types
      class Object < ::GraphQL::Schema::Scalar
        description "Object"

        class << self
          def coerce_input(value, context)
            validate_and_return_object(value)
          end

          def coerce_result(value, context)
            validate_and_return_object(value)
          end

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
