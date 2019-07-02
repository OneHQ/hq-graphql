require 'rails_helper'

describe ::HQ::GraphQL::Types::Object do
  let(:hql_object_klass) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "TestQuery"

      field :valid_object, ::HQ::GraphQL::Types::Object, null: false
      field :invalid_object, ::HQ::GraphQL::Types::Object, null: false

      def valid_object
        { name: object.name }
      end

      def invalid_object
        :not_an_object
      end
    end
  end

  let(:query) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "Query"

      field :advisor, AdvisorType, null: false do
        argument :filters, ::HQ::GraphQL::Types::Object, required: true
      end

      def advisor(filters:)
        Advisor.find_by(filters)
      end
    end
  end

  let(:schema) do
    Class.new(GraphQL::Schema) do
      query(Query)
    end
  end

  let(:query_str) do
    <<-GRAPHQL
      query findAdvisor($filters: Object!){
        advisor(filters: $filters) {
          validObject
        }
      }
    GRAPHQL
  end

  let(:invalid_query_str) do
    <<-GRAPHQL
      query findAdvisor($filters: Object!){
        advisor(filters: $filters) {
          invalidObject
        }
      }
    GRAPHQL
  end

  let(:advisor) { FactoryBot.create(:advisor) }
  let(:advisor_filter) { { name: advisor.name } }

  before(:each) do
    stub_const("AdvisorType", hql_object_klass)
    stub_const("Query", query)
  end

  describe ".coerce_result" do
    it "returns an object" do
      results = schema.execute(query_str, variables: { filters: advisor_filter })
      expect(results["data"]["advisor"]["validObject"]).to eql({ name: advisor.name })
    end

    it "raises an error when returning am invalid object " do
      expect { schema.execute(invalid_query_str, variables: { filters: advisor_filter }) }.to raise_error(
        ::GraphQL::CoercionError, ":not_an_object is not a valid Object"
      )
    end
  end

  describe ".coerce_input" do
    it "accepts an object as input" do
      result = schema.execute(query_str, variables: { filters: advisor_filter })
      expect(result["data"]["advisor"]["validObject"]).to eql({ name: advisor.name })
    end

    it "raises an error when an argument is an invalid object" do
      result = schema.execute(query_str, variables: { filters: advisor.name })
      aggregate_failures do
        expect(result["errors"].length).to eql(1)
        expect(result["errors"][0]["message"]).to eql("Variable filters of type Object! was provided invalid value")
      end
    end
  end
end
