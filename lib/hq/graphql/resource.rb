require "hq/graphql/resource/mutation"

module HQ
  module GraphQL
    module Resource

      def self.included(base)
        ::HQ::GraphQL.types << base
        base.include Scalars
        base.extend ClassMethods
      end

      module ClassMethods
        attr_writer :graphql_name, :model_name

        def find_record(attrs, context)
          primary_key = model_klass.primary_key.to_sym
          primary_key_value = attrs[primary_key]
          scope(context).find_by(primary_key => primary_key_value)
        end

        def graphql_name
          @graphql_name || model_name.demodulize
        end

        def model_name
          @model_name || name.demodulize
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

        def query_klass
          @query_klass ||= build_graphql_object
        end

        protected

        def default_scope(&block)
          @default_scope = block
        end

        def input(**options, &block)
          @input_klass = build_input_object(**options, &block)
        end

        def mutations(create: true, update: true, destroy: true)
          scoped_graphql_name = graphql_name
          scoped_model_name = model_name
          scoped_self = self

          if create
            create_mutation = ::HQ::GraphQL::Resource::Mutation.build(model_name, graphql_name: "#{scoped_graphql_name}Create") do
              define_method(:resolve) do |**args|
                resource = scoped_self.model_klass.new
                resource.assign_attributes(args[:attributes].format_nested_attributes)
                if resource.save
                  {
                    resource: resource,
                    errors: {},
                  }
                else
                  {
                    resource: nil,
                    errors: errors_from_resource(resource)
                  }
                end
              end

              lazy_load do
                argument :attributes, ::HQ::GraphQL::Inputs[scoped_model_name], required: true
              end
            end

            mutation_klasses["create_#{scoped_graphql_name.underscore}"] = create_mutation
          end

          if update
            update_mutation = ::HQ::GraphQL::Resource::Mutation.build(
              model_name,
              graphql_name: "#{scoped_graphql_name}Update",
              require_primary_key: true
            ) do
              define_method(:resolve) do |**args|
                resource = scoped_self.find_record(args, context)

                if resource
                  resource.assign_attributes(args[:attributes].format_nested_attributes)
                  if resource.save
                    {
                      resource: resource,
                      errors: {},
                    }
                  else
                    {
                      resource: nil,
                      errors: errors_from_resource(resource)
                    }
                  end
                else
                  {
                    resource: nil,
                    errors: { resource: "Unable to find #{scoped_graphql_name}" }
                  }
                end
              end

              lazy_load do
                argument :attributes, ::HQ::GraphQL::Inputs[scoped_model_name], required: true
              end
            end

            mutation_klasses["update_#{scoped_graphql_name.underscore}"] = update_mutation
          end

          if destroy
            destroy_mutation = ::HQ::GraphQL::Resource::Mutation.build(
              model_name,
              graphql_name: "#{scoped_graphql_name}Destroy",
              require_primary_key: true
            ) do
              define_method(:resolve) do |**attrs|
                resource = scoped_self.find_record(attrs, context)

                if resource
                  if resource.destroy
                    {
                      resource: resource,
                      errors: {},
                    }
                  else
                    {
                      resource: nil,
                      errors: errors_from_resource(resource)
                    }
                  end
                else
                  {
                    resource: nil,
                    errors: { resource: "Unable to find #{scoped_graphql_name}" }
                  }
                end
              end
            end

            mutation_klasses["destroy_#{scoped_graphql_name.underscore}"] = destroy_mutation
          end
        end

        def query(**options, &block)
          @query_klass = build_graphql_object(**options, &block)
        end

        def def_root(field_name, is_array: false, null: true, &block)
          graphql = self
          resolver = -> {
            Class.new(::GraphQL::Schema::Resolver) do
              type = is_array ? [graphql.query_klass] : graphql.query_klass
              type type, null: null
              class_eval(&block) if block
            end
          }
          ::HQ::GraphQL.root_queries << {
            field_name: field_name, resolver: resolver
          }
        end

        def root_query(find_one: true, find_all: true)
          field_name = graphql_name.underscore
          scoped_self = self

          if find_one
            def_root field_name, is_array: false, null: true do
              klass = scoped_self.model_klass
              primary_key = klass.primary_key
              pk_column = klass.columns.detect { |c| c.name == primary_key.to_s }

              argument primary_key, ::HQ::GraphQL::Types.type_from_column(pk_column), required: true

              define_method(:resolve) do |**attrs|
                scoped_self.find_record(attrs, context)
              end
            end
          end

          if find_all
            def_root field_name.pluralize, is_array: true, null: false do
              define_method(:resolve) do |**attrs|
                scoped_self.scope(context).all
              end
            end
          end
        end

        def scope(context)
          scope = model_klass
          scope = ::HQ::GraphQL.default_scope(scope, context)
          @default_scope&.call(scope, context) || scope
        end

        private

        def build_graphql_object(**options, &block)
          scoped_graphql_name = graphql_name
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

      end
    end
  end
end
