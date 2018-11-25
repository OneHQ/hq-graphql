module HQ
  module GraphQL
    module ActiveRecordExtensions
      class Error < StandardError
        MISSING_MODEL_MSG = "Your GraphQL object must be connected to a model: `::HQ::GraphQL::Object.with_model 'User'`".freeze
        MISSING_ATTR_MSG = "Can't find attr %{model}.%{attr}'`".freeze
        MISSING_ASSOC_MSG = "Can't find association %{model}.%{assoc}'`".freeze
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        attr_accessor :model_name,
                    :auto_load_attributes,
                    :auto_load_associations

        def lazy_load(&block)
          @lazy_load ||= []
          @lazy_load << block if block
          @lazy_load
        end

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
          model_klass.columns_hash[attr.to_s] || raise(Error, Error::MISSING_ATTR_MSG % { model: model_name, attr: attr })
        end

        def association_from_model(association)
          model_klass.reflect_on_association(association) || raise(Error, Error::MISSING_ASSOC_MSG % { model: model_name, assoc: association })
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

        def validate_model!
          lazy_load do
            model_name || raise(Error, Error::MISSING_MODEL_MSG)
          end
        end

      end
    end
  end
end
