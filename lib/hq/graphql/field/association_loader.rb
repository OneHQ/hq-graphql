# typed: false
# frozen_string_literal: true

module HQ
  module GraphQL
    module Field
      class AssociationLoader < ::GraphQL::Schema::Field
        attr_reader :loader_klass

        def initialize(*args, loader_klass: nil, **options, &block)
          super(*args, **options, &block)
          @loader_klass = loader_klass
        end

        def resolve_field(object, args, ctx)
          if loader_klass.present? && !!::GraphQL::Batch::Executor.current && object.object
            Loaders::Association.for(loader_klass.constantize, original_name).load(object.object).then do
              super
            end
          else
            super
          end
        end
      end
    end
  end
end
