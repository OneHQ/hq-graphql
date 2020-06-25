# frozen_string_literal: true

module HQ
  module GraphQL
    class Config < Struct.new(
      :authorize,
      :authorize_field,
      :default_object_class,
      :default_scope,
      :extract_class,
      :resource_lookup,
      :use_experimental_associations,
      keyword_init: true
    )
      def initialize(
        default_scope: ->(scope, _context) { scope },
        extract_class: ->(klass) { klass.to_s.gsub(/^Resources|Resource$/, "") },
        resource_lookup: ->(klass) { "::Resources::#{klass}Resource".safe_constantize || "::Resources::#{klass}".safe_constantize },
        **options
      )
        super
      end
    end
  end
end
