# frozen_string_literal: true

require "hq/graphql/ext/active_record_extensions"
require "hq/graphql/inputs"
require "hq/graphql/types"

module HQ
  module GraphQL
    module Ext
      module InputObjectExtensions
        def self.included(klass)
          klass.include Scalars
          klass.include InstanceMethods
          klass.include ActiveRecordExtensions
          klass.extend ActiveRecordExtensions
          klass.extend ClassMethods
        end

        module InstanceMethods
          # Recursively format attributes so that they are compatible with `accepts_nested_attributes_for`
          def format_nested_attributes
            self.each.inject({}) do |formatted_attrs, (key, value) |
              if self.class.nested_attributes.include?(key.to_s)
                formatted_value =
                  if value.is_a?(Array)
                    value.map(&:format_nested_attributes)
                  elsif value
                    value.format_nested_attributes
                  end

                formatted_attrs[:"#{key}_attributes"] = formatted_value if formatted_value
              elsif key.to_s == "x"
                formatted_attrs[:X] = value
              else
                formatted_attrs[key] = value
              end
              formatted_attrs
            end
          end
        end

        module ClassMethods
          #### Class Methods ####
          def with_model(model_name, attributes: true, associations: false, auto_nil: nil, enums: true, excluded_inputs: [])
            self.model_name = model_name
            self.auto_load_attributes = attributes
            self.auto_load_associations = associations
            self.auto_load_enums = enums

            lazy_load do
              excluded_inputs += ::HQ::GraphQL.excluded_inputs

              model_columns.each do |column|
                argument_from_column(column, auto_nil: auto_nil) unless excluded_inputs.include?(column.name.to_sym)
              end

              model_associations.each do |association|
                argument_from_association(association, auto_nil: auto_nil) unless excluded_inputs.include?(association.name.to_sym)
              end

              argument :X, String, required: false
            end
          end

          def nested_attributes
            @nested_attributes ||= Set.new
          end

          private

          def argument_from_association(association, auto_nil:)
            is_enum = is_enum?(association)
            input_or_type = is_enum ? ::HQ::GraphQL::Types[association.klass] : ::HQ::GraphQL::Inputs[association.klass]
            name = association.name
            return if argument_exists?(name)

            case association.macro
            when :has_many
              argument name, [input_or_type], required: false
            when :has_one
              argument name, input_or_type, required: auto_nil.nil? ? has_presence_validation?(association) : auto_nil
            else
              argument name, input_or_type, required: auto_nil.nil? ? association_required?(association) : auto_nil
            end

            return if is_enum

            if !model_klass.nested_attributes_options.key?(name.to_sym)
              model_klass.accepts_nested_attributes_for name, allow_destroy: true
            end

            nested_attributes << name.to_s
          rescue ::HQ::GraphQL::Inputs::Error
            nil
          end

          def argument_from_column(column, auto_nil:)
            name = column.name
            return if argument_exists?(name)
            argument name, ::HQ::GraphQL::Types.type_from_column(column), required: auto_nil.nil? ? column.null : auto_nil
          end

          def argument_exists?(name)
            !!arguments[camelize(name)]
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

::GraphQL::Schema::InputObject.include ::HQ::GraphQL::Ext::InputObjectExtensions
