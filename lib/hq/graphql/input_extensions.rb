module HQ
  module GraphQL
    module InputExtensions

      def self.included(base)
        base.include Scalars
        base.include ::HQ::GraphQL::ActiveRecordExtensions
        base.extend(ClassMethods)
      end

      module ClassMethods

        def with_model(model_name, attributes: true, associations: false)
          self.model_name = model_name
          self.auto_load_attributes = attributes
          self.auto_load_associations = associations

          lazy_load do
            model_columns.each do |column|
              argument_from_column(column)
            end

            model_associations.each do |association|
              argument_from_association association
            end
          end
        end

        private

        def argument_from_association(association)
          input = ::HQ::GraphQL::Inputs[association.klass]
          name = association.name
          name_attributes = "#{name}_attributes"
          case association.macro
          when :has_many
            argument name_attributes, [input], required: false
          else
            argument name_attributes, input, required: false
          end

          if !model_klass.nested_attributes_options.keys.include?(name.to_sym)
            model_klass.accepts_nested_attributes_for name, allow_destroy: true
          end
        rescue ::HQ::GraphQL::Inputs::Error
          nil
        end

        def argument_from_column(column)
          argument column.name, ::HQ::GraphQL::Types.type_from_column(column), required: false
        end

      end
    end
  end
end
