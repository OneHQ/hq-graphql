module HQ
  module GraphQL
    class RootQuery < ::HQ::GraphQL::Object

      def self.inherited(base)
        super
        base.class_eval do
          lazy_load do
            ::HQ::GraphQL.root_queries.each do |graphql|
              klass = graphql.model_klass
              field_name = klass.name.demodulize.underscore
              primary_key = klass.primary_key
              pk_column = klass.columns.detect { |c| c.name == primary_key.to_s }

              field field_name, graphql.query_klass, null: true do
                argument primary_key, ::HQ::GraphQL::Types.type_from_column(pk_column), required: true
              end

              define_method(field_name) do |**attrs|
                graphql.find_record(attrs, context)
              end
            end
          end
        end
      end

    end
  end
end
