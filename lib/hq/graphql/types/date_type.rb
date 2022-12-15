# frozen_string_literal: true

module Types
  class DateType < GraphQL::Schema::Scalar
    # https://github.com/rmosolgo/graphql-ruby/issues/2117
    # https://github.com/rmosolgo/graphql-ruby-demo/issues/27
    def self.coerce_input(input_value, _context)
      if input_value.instance_of? String
        Date.iso8601(input_value)
      else
        input_value
      end
    rescue ArgumentError
      nil
    end

    def self.coerce_result(ruby_value, _context)
      ruby_value.iso8601
    end
  end
end
