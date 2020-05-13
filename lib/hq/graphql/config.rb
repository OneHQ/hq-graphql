# frozen_string_literal: true

module HQ
  module GraphQL
    class Config < Struct.new(:authorize, :authorize_field, :default_scope, :resource_lookup, keyword_init: true)
      def initialize(
        default_scope: ->(scope, _context) { scope },
        resource_lookup: ->(klass) { "::Resources::#{klass}".safe_constantize },
        **options
      )
        super
      end
    end
  end
end
