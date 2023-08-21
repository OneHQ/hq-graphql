# frozen_string_literal: true

require "hq/graphql/ext/active_record_extensions"
require "hq/graphql/field"
require "hq/graphql/field_extension/association_loader_extension"
require "hq/graphql/field_extension/paginated_arguments"
require "hq/graphql/field_extension/paginated_loader"
require "hq/graphql/object_association"
require "hq/graphql/types"

module HQ
  module GraphQL
    module Ext
      module ObjectExtensions
        def self.included(klass)
          klass.include Scalars
          klass.include ActiveRecordExtensions
          klass.extend ObjectAssociation
          klass.singleton_class.prepend PrependMethods
          klass.field_class Field
        end

        module PrependMethods
          def authorize_action(action)
            self.authorized_action = action
          end

          def authorized?(object, context)
            super && ::HQ::GraphQL.authorized?(authorized_action, object, context)
          end

          def with_model(model_name, attributes: true, associations: true, auto_nil: true, enums: true)
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

          private
          attr_writer :authorized_action

          def authorized_action
            @authorized_action ||= :read
          end

          def field_from_association(association, auto_nil:, internal_association: false, &block)
            association_klass = association.klass
            name              = association.name.to_s
            return if field_exists?(name)

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
            when :has_one
              field name, type, null: !auto_nil || !has_presence_validation?(association), klass: model_name do
                extension FieldExtension::AssociationLoaderExtension, klass: klass
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
            return if field_exists?(name)

            field name, Types.type_from_column(column), null: !auto_nil || column.null,
            authorize: -> (obj, ctx) do
              restriction = ctx[:current_user]&.restrictions&.detect { |el|
                (el.resource.name == name || el.resource.alias == name) &&
                el.restriction_operation_id == "HasHelpers::RestrictionOperation::::View" &&
                el.resource.resource_type_id != "HasHelpers::ResourceType::::RequiredField"
              }
              return false if restriction.present?
              true
            end
          end

          def field_exists?(name)
            !!fields[camelize(name)]
          end

          def association_required?(association)
            !association.options[:optional] || has_presence_validation?(association)
          end

          def has_presence_validation?(association)
            model_klass.validators.any? do |validation|
              next unless validation.class == ActiveRecord::Validations::PresenceValidator && !(validation.options.include?(:if) || validation.options.include?(:unless))
              validation.attributes.any? { |a| a.to_s == association.name.to_s }
            end
          end
        end
      end
    end
  end
end

::GraphQL::Schema::Object.include ::HQ::GraphQL::Ext::ObjectExtensions
