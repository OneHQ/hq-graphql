# frozen_string_literal: true

require "hq/graphql/association_loader"

module HQ
  module GraphQL
    module FieldExtension
      class AssociationLoaderExtension < ::GraphQL::Schema::FieldExtension
        def resolve(object:, **_kwargs)
          AssociationLoader.for(options[:klass], field.original_name).load(object.object)
        end
      end
    end
  end
end
