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
        attr_accessor :model_name

        def find_record(attrs, context)
          primary_key = model_klass.primary_key.to_sym
          primary_key_value = attrs[primary_key]
          scope(context).find_by(primary_key => primary_key_value)
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
          scoped_model_name = model_name
          model_display_name = model_name.demodulize
          scoped_self = self

          if create
            create_mutation = ::HQ::GraphQL::Resource::Mutation.build(model_name, graphql_name: "#{model_display_name}Create") do
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

            mutation_klasses["create_#{model_display_name.underscore}"] = create_mutation
          end

          if update
            update_mutation = ::HQ::GraphQL::Resource::Mutation.build(
              model_name,
              graphql_name: "#{model_display_name}Update",
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
                      resource: resource,
                      errors: errors_from_resource(resource)
                    }
                  end
                else
                  {
                    resource: nil,
                    errors: { resource: "Unable to find #{model_display_name}" }
                  }
                end
              end

              lazy_load do
                argument :attributes, ::HQ::GraphQL::Inputs[scoped_model_name], required: true
              end
            end

            mutation_klasses["update_#{model_display_name.underscore}"] = update_mutation
          end

          if destroy
            destroy_mutation = ::HQ::GraphQL::Resource::Mutation.build(
              model_name,
              graphql_name: "#{model_display_name}Destroy",
              require_primary_key: true
            ) do
              define_method(:resolve) do |**attrs|
                resource = scoped_self.find_record(attrs, context)

                if resource
                  if resource.destroy
                    {
                      resource: resource,
                      errors: [],
                    }
                  else
                    {
                      resource: resource,
                      errors: errors_from_resource(resource)
                    }
                  end
                else
                  {
                    resource: nil,
                    errors: { resource: "Unable to find #{model_display_name}" }
                  }
                end
              end
            end

            mutation_klasses["destroy_#{model_display_name.underscore}"] = destroy_mutation
          end
        end

        def query(**options, &block)
          @query_klass = build_graphql_object(**options, &block)
        end

        def root_query
          ::HQ::GraphQL.root_queries << self
        end

        def scope(context)
          scope = model_klass
          scope = ::HQ::GraphQL.default_scope(scope, context)
          @default_scope&.call(scope, context) || scope
        end

        private

        def build_graphql_object(**options, &block)
          scoped_model_name = model_name
          Class.new(::HQ::GraphQL::Object) do
            graphql_name scoped_model_name

            with_model scoped_model_name, **options

            class_eval(&block) if block
          end
        end

        def build_input_object(**options, &block)
          scoped_model_name = model_name
          Class.new(::HQ::GraphQL::InputObject) do
            graphql_name "#{scoped_model_name.demodulize}Input"

            with_model scoped_model_name, **options

            class_eval(&block) if block
          end
        end

      end
    end
  end
end
