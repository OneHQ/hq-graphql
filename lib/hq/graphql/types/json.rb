module HQ
  module GraphQL
    module Types
      class JSON < ::GraphQL::Schema::Scalar
        description "JSON"

        class << self
          def coerce_input(value, context)
            ::JSON.parse(value)
          end

          def coerce_result(value, context)
            value
          end

        end
      end
    end
  end
end
