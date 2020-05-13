# frozen_string_literal: true

module HQ
  module GraphQL
    module Inputs
      class Error < StandardError
        MISSING_TYPE_MSG = "The GraphQL type for `%{klass}` is missing."
      end

      def self.[](key)
        @inputs ||= Hash.new do |hash, klass|
          hash[klass] = klass_for(klass)
        end
        @inputs[key]
      end

      # Only being used in testing
      def self.reset!
        @inputs = nil
      end

      class << self
        private

        def klass_for(klass_or_string)
          klass = klass_or_string.is_a?(String) ? klass_or_string.constantize : klass_or_string
          type = find_type(klass)

          raise(Error, Error::MISSING_TYPE_MSG % { klass: klass.name }) if !type
          type.input_klass
        end

        def find_type(klass)
          ::HQ::GraphQL.resource_lookup(klass) || ::HQ::GraphQL.types.detect { |t| t.model_klass == klass }
        end
      end
    end
  end
end
