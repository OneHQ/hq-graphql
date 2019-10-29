# typed: true
# frozen_string_literal: true

module HQ
  module GraphQL
    class Object < ::GraphQL::Schema::Object
      include Scalars
      include ::HQ::GraphQL::ActiveRecordExtensions

      field_class ::HQ::GraphQL::Field::AssociationLoader

      def self.with_model(model_name, attributes: true, associations: true, auto_nil: true)
        self.model_name = model_name
        self.auto_load_attributes = attributes
        self.auto_load_associations = associations

        lazy_load do
          model_columns.each do |column|
            field_from_column(column, auto_nil: auto_nil)
          end

          model_associations.each do |association|
            field_from_association(association, auto_nil: auto_nil)
          end
        end
      end

      def self.to_graphql
        lazy_load!
        super
      end

      class << self
        private

        def field_from_association(association, auto_nil:)
          type = ::HQ::GraphQL::Types[association.klass]
          name = association.name
          case association.macro
          when :has_many
            field name, [type], null: false, loader_klass: model_name
          else
            field name, type, null: !auto_nil || !association_required?(association), loader_klass: model_name
          end
        rescue ::HQ::GraphQL::Types::Error
          nil
        end

        def field_from_column(column, auto_nil:)
          field column.name, ::HQ::GraphQL::Types.type_from_column(column), null: !auto_nil || column.null
        end

        def association_required?(association)
          !association.options[:optional] || model_klass.validators.any? do |validation|
            next unless validation.class == ActiveRecord::Validations::PresenceValidator
            validation.attributes.any? { |a| a.to_s == association.name.to_s }
          end
        end
      end
    end
  end
end
