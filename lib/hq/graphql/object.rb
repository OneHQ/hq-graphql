# frozen_string_literal: true

require "hq/graphql/active_record_extensions"
require "hq/graphql/field"
require "hq/graphql/field_extension/association_loader_extension"
require "hq/graphql/field_extension/paginated_arguments"
require "hq/graphql/field_extension/paginated_loader"
require "hq/graphql/object_association"
require "hq/graphql/types"

module HQ
  module GraphQL
    class Object < ::GraphQL::Schema::Object
      include Scalars
      include ActiveRecordExtensions
      extend ObjectAssociation

      field_class Field

      def self.authorize_action(action)
        self.authorized_action = action
      end

      def self.authorized?(object, context)
        super && ::HQ::GraphQL.authorized?(authorized_action, object, context)
      end

      def self.with_model(model_name, attributes: true, associations: true, auto_nil: true, enums: true)
        self.model_name = model_name
        self.auto_load_attributes = attributes
        self.auto_load_associations = associations
        self.auto_load_enums = enums

        lazy_load do
          model_columns.each do |column|
            field_from_column(column, auto_nil: auto_nil)
          end

          model_associations.each do |association|
            next if resource_reflections[association.name.to_s]
            field_from_association(association, auto_nil: auto_nil)
          end

          resource_reflections.values.each do |resource_reflection|
            reflection = resource_reflection.reflection(model_klass)
            next unless reflection
            field_from_association(reflection, auto_nil: auto_nil, internal_association: true, &resource_reflection.block)
          end
        end
      end

      def self.to_graphql
        lazy_load!
        super
      end

      class << self
        private
        attr_writer :authorized_action

        def authorized_action
          @authorized_action ||= :read
        end

        def field_from_association(association, auto_nil:, internal_association: false, &block)
          association_klass = association.klass
          name              = association.name.to_s
          return if fields[name]

          klass = model_klass
          type  = Types[association_klass]
          case association.macro
          when :has_many
            field name, [type], null: false, klass: model_name do
              if ::HQ::GraphQL.use_experimental_associations?
                extension FieldExtension::PaginatedArguments, klass: association_klass
                extension FieldExtension::PaginatedLoader, klass: klass, association: name, internal_association: internal_association
              else
                extension FieldExtension::AssociationLoaderExtension, klass: klass
              end
              instance_eval(&block) if block
            end
          else
            field name, type, null: !auto_nil || !association_required?(association), klass: model_name do
              extension FieldExtension::AssociationLoaderExtension, klass: klass
            end
          end
        rescue Types::Error
          nil
        end

        def field_from_column(column, auto_nil:)
          name = column.name
          return if fields[name]

          field name, Types.type_from_column(column), null: !auto_nil || column.null
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
