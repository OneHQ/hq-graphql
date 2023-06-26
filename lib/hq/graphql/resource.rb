# frozen_string_literal: true

require "hq/graphql/ext/enum_extensions"
require "hq/graphql/ext/input_object_extensions"
require "hq/graphql/ext/object_extensions"
require "hq/graphql/enum/filter_operation"
require "hq/graphql/enum/sort_by"
require "hq/graphql/field_extension/paginated_arguments"
require "hq/graphql/filters"
require "hq/graphql/resource/auto_mutation"
require "hq/graphql/scalars"
require "hq/graphql/pagination_connection_type"

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
          @input_klass ||= const_set(:Input, build_input_object)
        end

        def nil_input_klass
          @nil_input_klass ||= const_set(:NilInput, build_input_object(name: "#{graphql_name}Nil"))
        end

        def nil_query_object
          @nil_query_object ||= const_set(:NilQuery, build_graphql_object(name: "#{graphql_name}Copy", auto_nil: false))
        end

        def query_object
          @query_object ||= begin
            qo =
              if @query_object_options
                options, block = @query_object_options
                @query_object_options = nil
                build_graphql_object(**options, &block)
              else
                build_graphql_object
              end
            remove_const(:Query) if const_defined?(:Query, false)
            const_set(:Query, qo)
          end
        end

        def sort_fields_enum
          @sort_fields_enum || ::HQ::GraphQL::Enum::SortBy
        end

        def const_missing(constant_name)
          constant_name = constant_name.to_sym
          case constant_name
          when :Query
            query_object
          when :NilQuery
            nil_query_object
          when :Input
            input_klass
          when :NilInput
            nil_input_klass
          when :FilterInput
            filter_input
          when :FilterFields
            filter_fields_enum
          else
            super
          end
        end

        def filter_input
          @filter_input ||= begin
            scoped_self = self

            input_class = Class.new(::GraphQL::Schema::InputObject) do
              graphql_name "#{scoped_self.graphql_name}QueryFilterInput"

              argument :field, scoped_self.filter_fields_enum, required: true
              argument :operation, Enum::FilterOperation, required: true
              argument :is_or, ::GraphQL::Schema::Scalar::Boolean, required: false
              argument :value, String, required: false
              argument :array_values, [String], required: false
              argument :column_value, scoped_self.filter_fields_enum, required: false
            end

            const_set(:FilterInput, input_class)
          end
        end

        def filter_fields_enum
          @filter_fields_enum ||= begin
            scoped_self = self

            enum_class = Class.new(::GraphQL::Schema::Enum) do
              graphql_name "#{scoped_self.graphql_name}QueryFilterFields"

              lazy_load do
                scoped_self.model_klass.columns.sort_by(&:name).each do |column|
                  next unless HQ::GraphQL::Filters.supported?(column)
                  value column.name.camelize(:lower), value: column
                end
              end
            end

            const_set(:FilterFields, enum_class)
          end
        end

        protected

        def default_scope(&block)
          @default_scope = block
        end

        def input(**options, &block)
          @input_klass = build_input_object(**options, &block)
        end

        def nil_input(**options, &block)
          @nil_input_klass = build_input_object(**options, name: "#{options.try(:name) || graphql_name}Nil", &block)
        end

        # mutations generates available default mutations on RootMutation for a certain resource
        # Parameters:
        # create => adds create operation
        # copy => adds copy operation
        # update => adds update operation
        # destroy => adds destroy operation
        def mutations(create: true, copy: true, update: true, destroy: true)
          scoped_self = self
          if create
            mutation_klasses["create_#{graphql_name.underscore}"] = build_create
            # new_resource query will be created only if create mutation exist
            klass = scoped_self.model_klass
            def_root "new_#{graphql_name.underscore}", is_array: false, null: true, new_query: true do

              argument :attributes, ::HQ::GraphQL::NilInputs[scoped_self.model_name], required: false

              define_method(:resolve) do |**attrs|
                resource_instance = klass.new(attrs[:attributes].to_h)
                resource_instance.hydrate
                resource_instance
              end
            end
          end
          mutation_klasses["copy_#{graphql_name.underscore}"] = build_copy if copy
          mutation_klasses["update_#{graphql_name.underscore}"] = build_update if update
          mutation_klasses["destroy_#{graphql_name.underscore}"] = build_destroy if destroy
        end

        def query(**options, &block)
          @query_object_options = [options, block]
        end

        def query_class(klass)
          @query_class = klass
        end

        def sort_fields(*fields)
          self.sort_fields_enum = fields
        end

        def excluded_inputs(*fields)
          @excluded_inputs = fields
        end

        # def_root generates available queries on RootQuery
        # this method can be used to create resource's custom queries
        # Parameters:
        # field_name => operation name in RootQuery
        # is_array => if true, creates List query. false for single record query.
        # null => sets if result can be null.
        # new_query it's only used to stablish the correct Object type that must be configured in the resolver.
        # new_query is necessary because the same block of code is used to create getById and new_resource queries.
        # block => code block that it's going to be executed to get the result.
        def def_root(field_name, is_array: false, null: true, new_query: false, &block)
          resource = self
          suffix = is_array ? "List" : ""
          if is_array
            connection_resolver = -> {
              klass = Class.new(::GraphQL::Schema::Resolver) do
                type = resource.query_object.connection_type

                type type, null: null
                class_eval(&block) if block
              end

              constant_name = "#{field_name.to_s.classify}Resolver"
              resource.send(:remove_const, constant_name) if resource.const_defined?(constant_name, false)
              resource.const_set(constant_name, klass)
            }
            ::HQ::GraphQL.root_queries << {
              field_name: field_name, resolver: connection_resolver, model_name: model_name
            }
          else
            resolver = -> {
              klass = Class.new(::GraphQL::Schema::Resolver) do
                type = new_query ? resource.nil_query_object : resource.query_object
                type type, null: null
                class_eval(&block) if block
              end

              constant_name = "#{field_name.to_s.classify}Resolver#{suffix}"
              resource.send(:remove_const, constant_name) if resource.const_defined?(constant_name, false)
              resource.const_set(constant_name, klass)
            }
            ::HQ::GraphQL.root_queries << {
              field_name: field_name, resolver: resolver, model_name: model_name
            }
          end
        end

        # root_query generates available default queries on RootQuery for a certain resource
        # Parameters:
        # find_one => getById query
        # find_all => list query
        # limit_max => max amount of record that can be obtained if 'first/last' is not provided
        def root_query(find_one: true, find_all: true, limit_max: 250)
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
              extension FieldExtension::PaginatedArguments, klass: scoped_self.model_klass
              argument :filters, [scoped_self.filter_input], required: false

              define_method(:resolve) do |filters: nil, limit: nil, offset: nil, sort_by: nil, sort_order: nil, **_attrs|
                filters_scope = ::HQ::GraphQL::Filters.new(filters, scoped_self.model_klass)
                filters_scope.validate!

                scope = scoped_self.scope(context).all.merge(filters_scope.to_scope)
                offset = [0, *offset].max

                # set limit_max if first/last N is not provided
                scope = if limit.present? || !(context.query.provided_variables.symbolize_keys.keys & [:first, :last]).any?
                  limit = [[limit_max, *limit].min, 0].max
                  scope.limit(limit).offset(offset)
                else
                  scope.offset(offset)
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
          object_class = @query_class || ::HQ::GraphQL.default_object_class || ::GraphQL::Schema::Object
          Class.new(object_class) do
            graphql_name scoped_graphql_name

            with_model scoped_model_name, **options

            connection_type_class PaginationConnectionType

            class_eval(&block) if block
          end
        end

        def build_input_object(name: graphql_name, **options, &block)
          scoped_graphql_name = name
          scoped_model_name = model_name
          scoped_excluded_inputs = @excluded_inputs || []

          Class.new(::GraphQL::Schema::InputObject) do
            graphql_name "#{scoped_graphql_name}Input"

            with_model scoped_model_name, excluded_inputs: scoped_excluded_inputs, **options

            class_eval(&block) if block
          end
        end

        def sort_fields_enum=(fields)
          @sort_fields_enum ||= Class.new(::HQ::GraphQL::Enum::SortBy).tap do |c|
            c.graphql_name "#{graphql_name}Sort"
            const_set(:Sort, c)
          end

          Array(fields).each do |field|
            @sort_fields_enum.value field.to_s.classify, value: field
          end
        end
      end
    end
  end
end
