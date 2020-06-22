# frozen_string_literal: true

require "hq/graphql/enum/sort_by"
require "hq/graphql/field_extension/paginated_arguments"
require "hq/graphql/input_object"
require "hq/graphql/object"
require "hq/graphql/resource/auto_mutation"
require "hq/graphql/scalars"

module HQ
  module GraphQL
    module Resource
      def self.included(base)
        super
        ::HQ::GraphQL.resources << base
        base.include Scalars
        base.include ::GraphQL::Types
        base.extend ClassMethods
      end

      module ClassMethods
        include AutoMutation

        attr_writer :graphql_name, :model_name

        def scope(context)
          scope = model_klass
          scope = ::HQ::GraphQL.default_scope(scope, context)
          @default_scope&.call(scope, context) || scope
        end

        def find_record(attrs, context)
          primary_key = model_klass.primary_key.to_sym
          primary_key_value = attrs[primary_key]
          scope(context).find_by(primary_key => primary_key_value)
        end

        def new_record(context)
          scope(context).new
        end

        def graphql_name
          @graphql_name || model_name.demodulize
        end

        def model_name
          @model_name || ::HQ::GraphQL.extract_class(self)
        end

        def model_klass
          @model_klass ||= model_name&.safe_constantize
        end

        def mutation_klasses
          @mutation_klasses ||= {}.with_indifferent_access
        end

        def input_klass
          @input_klass ||= build_input_object
        end

        def nil_query_klass
          @nil_query_klass ||= build_graphql_object(name: "#{graphql_name}Copy", auto_nil: false)
        end

        def query_klass
          @query_klass ||= build_graphql_object
        end

        def sort_fields_enum
          @sort_fields_enum || ::HQ::GraphQL::Enum::SortBy
        end

        protected

        def default_scope(&block)
          @default_scope = block
        end

        def input(**options, &block)
          @input_klass = build_input_object(**options, &block)
        end

        def mutations(create: true, copy: true, update: true, destroy: true)
          mutation_klasses["create_#{graphql_name.underscore}"] = build_create if create
          mutation_klasses["copy_#{graphql_name.underscore}"] = build_copy if copy
          mutation_klasses["update_#{graphql_name.underscore}"] = build_update if update
          mutation_klasses["destroy_#{graphql_name.underscore}"] = build_destroy if destroy
        end

        def query(**options, &block)
          @query_klass = build_graphql_object(**options, &block)
        end

        def sort_fields(*fields)
          self.sort_fields_enum = fields
        end

        def def_root(field_name, is_array: false, null: true, &block)
          resource = self
          resolver = -> {
            Class.new(::GraphQL::Schema::Resolver) do
              type = is_array ? [resource.query_klass] : resource.query_klass
              type type, null: null
              class_eval(&block) if block
            end
          }
          ::HQ::GraphQL.root_queries << {
            field_name: field_name, resolver: resolver, model_name: model_name
          }
        end

        def root_query(find_one: true, find_all: true, pagination: true, limit_max: 250)
          field_name = graphql_name.underscore
          scoped_self = self

          if find_one
            def_root field_name, is_array: false, null: true do
              klass = scoped_self.model_klass
              primary_key = klass.primary_key

              argument primary_key, ::GraphQL::Types::ID, required: true

              define_method(:resolve) do |**attrs|
                scoped_self.find_record(attrs, context)
              end
            end
          end

          if find_all
            def_root field_name.pluralize, is_array: true, null: false do
              extension FieldExtension::PaginatedArguments, klass: scoped_self.model_klass if pagination

              define_method(:resolve) do |limit: nil, offset: nil, sort_by: nil, sort_order: nil, **_attrs|
                scope = scoped_self.scope(context).all

                if pagination || page || limit
                  offset = [0, *offset].max
                  limit = [[limit_max, *limit].min, 0].max
                  scope = scope.limit(limit).offset(offset)
                end

                sort_by ||= :updated_at
                sort_order ||= :desc
                # There should be no risk for SQL injection since an enum is being used for both sort_by and sort_order
                scope = scope.reorder(sort_by => sort_order)

                scope
              end
            end
          end
        end

        private

        def build_graphql_object(name: graphql_name, **options, &block)
          scoped_graphql_name = name
          scoped_model_name = model_name
          Class.new(::HQ::GraphQL::Object) do
            graphql_name scoped_graphql_name

            with_model scoped_model_name, **options

            class_eval(&block) if block
          end
        end

        def build_input_object(**options, &block)
          scoped_graphql_name = graphql_name
          scoped_model_name = model_name
          Class.new(::HQ::GraphQL::InputObject) do
            graphql_name "#{scoped_graphql_name}Input"

            with_model scoped_model_name, **options

            class_eval(&block) if block
          end
        end

        def sort_fields_enum=(fields)
          @sort_fields_enum ||= Class.new(::HQ::GraphQL::Enum::SortBy).tap do |c|
            c.graphql_name "#{graphql_name}Sort"
          end

          Array(fields).each do |field|
            @sort_fields_enum.value field.to_s.classify, value: field
          end
        end
      end
    end
  end
end
