# frozen_string_literal: true

module HQ
  module GraphQL
    module Ext
      module MutationExtensions
        def self.included(klass)
          klass.include Scalars
          klass.include ActiveRecordExtensions
          klass.singleton_class.prepend PrependMethods
        end

        module PrependMethods
          def generate_payload_type
            lazy_load!
            super
          end
        end
      end
    end
  end
end

::GraphQL::Schema::Mutation.include ::HQ::GraphQL::Ext::MutationExtensions
