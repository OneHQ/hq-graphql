# frozen_string_literal: true

module HQ
  module GraphQL
    class RootQuery < ::HQ::GraphQL::Object
      def self.inherited(base)
        super
        base.class_eval do
          lazy_load do
            ::HQ::GraphQL.root_queries.each do |field_name:, resolver:, model_name:|
              field field_name, resolver: resolver.call, klass: model_name
            end
          end
        end
      end
    end
  end
end
