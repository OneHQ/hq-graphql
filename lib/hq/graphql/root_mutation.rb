# frozen_string_literal: true

module HQ
  module GraphQL
    class RootMutation < ::HQ::GraphQL::Object
      def self.inherited(base)
        super
        base.class_eval do
          lazy_load do
            ::HQ::GraphQL.resources.each do |type|
              type.mutation_klasses.each do |mutation_name, klass|
                field mutation_name, mutation: klass
              end
            end
          end
        end
      end
    end
  end
end
