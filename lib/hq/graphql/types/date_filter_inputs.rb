# frozen_string_literal: true

module HQ
  module GraphQL
    module Types
      class DateFilterUnit < ::GraphQL::Schema::Enum
        graphql_name "DateFilterUnit"

        value "DAY"
        value "WEEK"
        value "MONTH"
        value "YEAR"
      end

      class DateFilterDirection < ::GraphQL::Schema::Enum
        graphql_name "DateFilterDirection"

        value "AGO"
        value "FROM_NOW"
      end

      class DateFilterAnchor < ::GraphQL::Schema::Enum
        graphql_name "DateFilterAnchor"

        value "START_OF"
        value "END_OF"
      end

      class DateFilterPosition < ::GraphQL::Schema::Enum
        graphql_name "DateFilterPosition"

        value "LAST"
        value "THIS"
        value "NEXT"
      end

      class DateFilterKind < ::GraphQL::Schema::Enum
        graphql_name "DateFilterKind"

        value "ABSOLUTE"
        value "RELATIVE"
        value "ANCHOR"
      end

      class DateFilterAbsoluteInput < ::GraphQL::Schema::InputObject
        graphql_name "DateFilterAbsoluteInput"

        argument :value, ::GraphQL::Types::ISO8601DateTime, required: true
      end

      class DateFilterRelativeInput < ::GraphQL::Schema::InputObject
        graphql_name "DateFilterRelativeInput"

        argument :amount, ::GraphQL::Types::Int, required: true
        argument :unit, DateFilterUnit, required: true
        argument :direction, DateFilterDirection, required: true
      end

      class DateFilterAnchoredInput < ::GraphQL::Schema::InputObject
        graphql_name "DateFilterAnchoredInput"

        argument :position, DateFilterPosition, required: true
        argument :period, DateFilterUnit, required: true
        argument :anchor, DateFilterAnchor, required: true
      end

      class DateFilterValueInput < ::GraphQL::Schema::InputObject
        graphql_name "DateFilterValueInput"

        argument :kind, DateFilterKind, required: true
        argument :absolute, DateFilterAbsoluteInput, required: false
        argument :relative, DateFilterRelativeInput, required: false
        argument :anchored, DateFilterAnchoredInput, required: false
      end

      class DateFilterRangeInput < ::GraphQL::Schema::InputObject
        graphql_name "DateFilterRangeInput"

        argument :from, DateFilterValueInput, required: true
        argument :to, DateFilterValueInput, required: true
      end
    end
  end
end
