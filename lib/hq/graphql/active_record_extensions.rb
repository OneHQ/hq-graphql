# typed: true
# frozen_string_literal: true

module HQ
  module GraphQL
    module ActiveRecordExtensions
      extend T::Sig
      extend T::Helpers

      class Error < StandardError
        MISSING_MODEL_MSG = "Your GraphQL object must be connected to a model: `::HQ::GraphQL::Object.with_model 'User'`"
        MISSING_ATTR_MSG = "Can't find attr %{model}.%{attr}'`"
        MISSING_ASSOC_MSG = "Can't find association %{model}.%{assoc}'`"
      end

      module ClassMethods
        extend T::Sig
        include Kernel

        attr_accessor :model_name,
                      :authorize_action,
                      :auto_load_attributes,
                      :auto_load_associations

        sig { params(block: T.nilable(T.proc.void)).returns(T::Array[T.proc.void]) }
        def lazy_load(&block)
          @lazy_load ||= []
          @lazy_load << block if block
          @lazy_load
        end

        sig { void }
        def lazy_load!
          lazy_load.map(&:call)
          @lazy_load = []
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
          model_associations =
            if auto_load_associations
              model_klass.reflect_on_all_associations
            else
              added_associations.map { |association| association_from_model(association) }
            end

          # validate removed_associations exist
          removed_associations.each { |association| association_from_model(association) }

          model_associations.reject { |a| removed_associations.include?(a.name.to_sym) }.sort_by(&:name)
        end

        private

        sig { params(attrs: T.any(String, Symbol)).void }
        def add_attributes(*attrs)
          validate_model!
          added_attributes.concat attrs.map(&:to_sym)
        end
        alias_method :add_attribute, :add_attributes
        alias_method :add_attrs, :add_attributes
        alias_method :add_attr, :add_attributes

        sig { params(attrs: T.any(String, Symbol)).void }
        def remove_attributes(*attrs)
          validate_model!
          removed_attributes.concat attrs.map(&:to_sym)
        end
        alias_method :remove_attribute, :remove_attributes
        alias_method :remove_attrs, :remove_attributes
        alias_method :remove_attr, :remove_attributes

        sig { params(associations: T.any(String, Symbol)).void }
        def add_associations(*associations)
          validate_model!
          added_associations.concat associations.map(&:to_sym)
        end
        alias_method :add_association, :add_associations

        sig { params(associations: T.any(String, Symbol)).void }
        def remove_associations(*associations)
          validate_model!
          removed_associations.concat associations.map(&:to_sym)
        end
        alias_method :remove_association, :remove_associations

        def model_klass
          @model_klass ||= model_name.constantize
        end

        sig { params(attr: Symbol).returns(T.untyped) }
        def column_from_model(attr)
          model_klass.columns_hash[attr.to_s] || raise(Error, Error::MISSING_ATTR_MSG % { model: model_name, attr: attr })
        end

        def association_from_model(association)
          model_klass.reflect_on_association(association) || raise(Error, Error::MISSING_ASSOC_MSG % { model: model_name, assoc: association })
        end

        sig { returns(T::Array[Symbol]) }
        def added_attributes
          @added_attributes ||= []
        end

        sig { returns(T::Array[Symbol]) }
        def removed_attributes
          @removed_attributes ||= []
        end

        sig { returns(T::Array[Symbol]) }
        def added_associations
          @added_associations ||= []
        end

        sig { returns(T::Array[Symbol]) }
        def removed_associations
          @removed_associations ||= []
        end

        sig { void }
        def validate_model!
          lazy_load do
            model_name || raise(Error, Error::MISSING_MODEL_MSG)
          end
        end
      end
      mixes_in_class_methods(ClassMethods)
    end
  end
end
