# frozen_string_literal: true

module HQ
  module GraphQL
    class Object < ::GraphQL::Schema::Object
      include Scalars
      include ::HQ::GraphQL::ActiveRecordExtensions

      def self.with_model(model_name, attributes: true, associations: true)
        self.model_name = model_name
        self.auto_load_attributes = attributes
        self.auto_load_associations = associations

        lazy_load do
          model_columns.each do |column|
            field_from_column(column)
          end

          model_associations.each do |association|
            field_from_association association
          end
        end
      end

      def self.to_graphql
        lazy_load!
        super
      end

      class << self
        private

        def field_from_association(association)
          type = ::HQ::GraphQL::Types[association.klass]
          name = association.name
          case association.macro
          when :has_many
            field name, [type], null: false
          else
            field name, type, null: true
          end
        rescue ::HQ::GraphQL::Types::Error
          nil
        end

        def field_from_column(column)
          field column.name, ::HQ::GraphQL::Types.type_from_column(column), null: true
        end
      end
    end
  end
end
