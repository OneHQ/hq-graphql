# frozen_string_literal: true

module HQ
  module GraphQL
    module Ext
      module ActiveRecordExtensions
        class ActiveRecordError < StandardError
          MISSING_MODEL_MSG = "Your GraphQL object must be connected to a model: `::GraphQL::Schema::Object.with_model 'User'`"
          MISSING_ATTR_MSG = "Can't find attr %{model}.%{attr}'`"
          MISSING_ASSOC_MSG = "Can't find association %{model}.%{assoc}'`"
        end

        def self.included(klass)
          klass.extend(ClassMethods)
        end

        module ClassMethods
          attr_accessor :model_name,
                        :authorize_action,
                        :auto_load_attributes,
                        :auto_load_associations,
                        :auto_load_enums

          def lazy_load(&block)
            @lazy_load ||= []
            if block
              ::HQ::GraphQL.lazy_load(self)
              @lazy_load << block
            end
            @lazy_load
          end

          def lazy_load!
            lazy_load.shift.call while lazy_load.length > 0
            @lazy_load = nil
          end

          def model_columns
            model_columns =
              if auto_load_attributes
                model_klass.columns
              else
                added_attributes.map { |attr| column_from_model(attr) }
              end

            # validate removed_attributes exist
            removed_attributes.each { |attr| column_from_model(attr) }

            model_columns.reject { |c| removed_attributes.include?(c.name.to_sym) }.sort_by(&:name)
          end

          def model_associations
            model_associations = []
            enums = model_klass.reflect_on_all_associations.select { |a| is_enum?(a) }
            associatons = model_klass.reflect_on_all_associations - enums

            if auto_load_enums
              model_associations.concat(enums)
            end

            if auto_load_associations
              model_associations.concat(associatons)
            end

            model_associations.concat(added_associations.map { |association| association_from_model(association) }).uniq

            # validate removed_associations exist
            removed_associations.each { |association| association_from_model(association) }

            model_associations.reject { |a| removed_associations.include?(a.name.to_sym) }.sort_by(&:name)
          end

          private

          def add_attributes(*attrs)
            validate_model!
            added_attributes.concat attrs.map(&:to_sym)
          end

          alias_method :add_attribute, :add_attributes
          alias_method :add_attrs, :add_attributes
          alias_method :add_attr, :add_attributes

          def remove_attributes(*attrs)
            validate_model!
            removed_attributes.concat attrs.map(&:to_sym)
          end

          alias_method :remove_attribute, :remove_attributes
          alias_method :remove_attrs, :remove_attributes
          alias_method :remove_attr, :remove_attributes

          def add_associations(*associations)
            validate_model!
            added_associations.concat associations.map(&:to_sym)
          end

          alias_method :add_association, :add_associations

          def remove_associations(*associations)
            validate_model!
            removed_associations.concat associations.map(&:to_sym)
          end

          alias_method :remove_association, :remove_associations

          def model_klass
            @model_klass ||= model_name.constantize
          end

          def column_from_model(attr)
            model_klass.columns_hash[attr.to_s] || raise(ActiveRecordError, ActiveRecordError::MISSING_ATTR_MSG % { model: model_name, attr: attr })
          end

          def association_from_model(association)
            model_klass.reflect_on_association(association) || raise(ActiveRecordError, ActiveRecordError::MISSING_ASSOC_MSG % { model: model_name, assoc: association })
          end

          def added_attributes
            @added_attributes ||= []
          end

          def removed_attributes
            @removed_attributes ||= []
          end

          def added_associations
            @added_associations ||= []
          end

          def removed_associations
            @removed_associations ||= []
          end

          def camelize(name)
            name.to_s.camelize(:lower)
          end

          def is_enum?(association)
            ::HQ::GraphQL.enums.include?(association.klass)
          end

          def validate_model!
            lazy_load do
              model_name || raise(ActiveRecordError, ActiveRecordError::MISSING_MODEL_MSG)
            end
          end
        end
      end
    end
  end
end
