require 'rails_helper'

describe ::HQ::GraphQL::Types::UUID do
  let(:hql_object_klass) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "TestQuery"

      field :name, ::HQ::GraphQL::Types::UUID, null: false
    end
  end

  let(:query) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "Query"

      field :advisor, AdvisorType, null: false do
        argument :id, ::HQ::GraphQL::Types::UUID, required: true
      end

      def advisor(id:)
        Advisor.find(id)
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
      query findAdvisor($id: UUID!){
        advisor(id: $id) {
          name
        }
      }
    GRAPHQL
  end

  before(:each) do
    stub_const("AdvisorType", hql_object_klass)
    stub_const("Query", query)
  end

  describe ".coerce_result" do
    it "raises an error on incorrect type" do
      advisor = FactoryBot.create(:advisor)
      expect { schema.execute(query_str, variables: { id: advisor.id }) }.to raise_error(
        ::GraphQL::CoercionError, "\"#{advisor.name}\" is not a valid UUID"
      )
    end
  end

  describe ".coerce_input" do
    it "displays an error message" do
      result = schema.execute(query_str, variables: { id: "1" })
      aggregate_failures do
        expect(result["errors"].length).to eql(1)
        expect(result["errors"][0]["message"]).to eql("Variable id of type UUID! was provided invalid value")
      end
    end
  end
end
