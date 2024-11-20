# frozen_string_literal: true

require "hq/graphql/enum/sort_by"
require "hq/graphql/enum/sort_order"

module HQ
  module GraphQL
    module FieldExtension
      class PaginatedArguments < ::GraphQL::Schema::FieldExtension
        def apply
          field.argument :offset, Integer, required: false
          field.argument :limit, Integer, required: false
          field.argument :sort_order, Enum::SortOrder, required: false

          resource = ::HQ::GraphQL.lookup_resource(options[:klass])
          enum = resource ? resource.sort_fields_enum : ::HQ::GraphQL::Enum::SortBy
          field.argument :sort_by, enum, required: false
        end
      end
    end
  end
end
