module HQ
  module GraphQL
    module InputExtensions

      def self.included(base)
        base.include Scalars
        base.include ::HQ::GraphQL::ActiveRecordExtensions
        base.include(InstanceMethods)
        base.extend(ClassMethods)
      end

      module InstanceMethods
        # Recursively format attributes so that they are compatible with `accepts_nested_attributes_for`
        def format_nested_attributes(attrs)
          attrs.inject({}) do |formatted_attrs, (key, value) |
            if self.class.nested_attributes.include?(key.to_s)
              formatted_attrs["#{key}_attributes"] = value.format_nested_attributes(value.to_h)
            else
              formatted_attrs[key] = value
            end
            formatted_attrs
          end
        end
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

        def nested_attributes
          @nested_attributes ||= Set.new
        end

        private

        def argument_from_association(association)
          input = ::HQ::GraphQL::Inputs[association.klass]
          name = association.name

          case association.macro
          when :has_many
            argument name, [input], required: false
          else
            argument name, input, required: false
          end

          if !model_klass.nested_attributes_options.keys.include?(name.to_sym)
            model_klass.accepts_nested_attributes_for name, allow_destroy: true
          end

          nested_attributes << name.to_s
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
