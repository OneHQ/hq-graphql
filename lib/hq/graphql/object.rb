module HQ
  module GraphQL
    class Object < ::GraphQL::Schema::Object
      include Scalars

      class Error < StandardError
        MISSING_MODEL_MSG = "Can't perform %{action} without connecting to a model: `::HQ::GraphQL::Object.with_model 'User'`".freeze
        MISSING_ATTR_MSG = "Can't find attr %{model}.%{attr}'`".freeze
        MISSING_ASSOC_MSG = "Can't find association %{model}.%{assoc}'`".freeze
      end

      def self.lazy_load(&block)
        @lazy_load ||= []
        @lazy_load << block if block
        @lazy_load
      end

      def self.with_model(model_name, attributes: true, associations: true)
        self.model_name = model_name

        lazy_load do
          if attributes
            model_klass.columns.reject { |c| removed_attrs.include?(c.name.to_sym) }.each do |column|
              field_from_column column
            end
          end

          if associations
            model_klass.reflect_on_all_associations.reject { |a| removed_associations.include?(a.name.to_sym) }.each do |association|
              field_from_association association
            end
          end
        end
      end

      def self.add_attr(attr)
        lazy_load do
          validate_model!(:add_attr)
          field_from_column model_column(attr)
        end
      end

      def self.remove_attrs(*attrs)
        removed_attrs.concat attrs.map(&:to_sym)
      end

      def self.remove_associations(*associations)
        removed_associations.concat associations.map(&:to_sym)
      end

      def self.add_association(association)
        lazy_load do
          validate_model!(:add_association)
          field_from_association model_association(association)
        end
      end

      def self.to_graphql
        lazy_load!
        super
      end

      class << self
        private

        attr_accessor :model_name
        attr_writer :removed_attrs, :removed_associations

        def lazy_load!
          lazy_load.map(&:call)
          @lazy_load = []
        end

        def model_klass
          @model_klass ||= model_name&.constantize
        end

        def model_column(attr)
          model_klass.columns_hash[attr.to_s] || raise(Error, Error::MISSING_ATTR_MSG % { model: model_name, attr: attr })
        end

        def model_association(association)
          model_klass.reflect_on_association(association) || raise(Error, Error::MISSING_ASSOC_MSG % { model: model_name, assoc: association })
        end

        def removed_attrs
          @removed_attrs ||= []
        end

        def removed_associations
          @removed_associations ||= []
        end

        def validate_model!(action)
          unless model_name
            raise Error, Error::MISSING_MODEL_MSG % { action: action }
          end
        end

        def field_from_association(association)
          name = association.name
          type = ::HQ::GraphQL::Types[association.klass]
          case association.macro
          when :has_many
            field name, [type], null: false
          else
            field name, type, null: true
          end
        end

        def field_from_column(column)
          field column.name, ::HQ::GraphQL::Types.type_from_column(column), null: column.null
        end

      end

    end
  end
end
