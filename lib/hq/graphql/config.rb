# frozen_string_literal: true

module HQ
  module GraphQL
    class Config < Struct.new(
      :authorize,
      :authorize_field,
      :authorize_nested_attributes,
      :default_object_class,
      :default_scope,
      :default_search_type,
      :extract_class,
      :resource_lookup,
      :use_experimental_associations,
      :nullable_associations,
      :nullable_root_collections,
      :authorize_association_target,
      :excluded_inputs,
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
