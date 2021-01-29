# frozen_string_literal: true

module HQ
  module GraphQL
    class RootQuery < ::GraphQL::Schema::Object
      def self.inherited(base)
        super
        base.class_eval do
          lazy_load do
            ::HQ::GraphQL.root_queries.each do |query|
              field query[:field_name], resolver: query[:resolver].call, klass: query[:model_name]
            end
          end
        end
      end
    end
  end
end
