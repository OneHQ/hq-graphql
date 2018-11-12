require 'rails_helper'

describe ::HQ::GraphQL::Types do

  describe ".[]" do
    let(:graphql_klass) do
      Class.new do
        include ::HQ::GraphQL::Resource

        self.model_name = "Advisor"

        query(attributes: false, associations: false) do
          field :custom_field, String, null: false
        end
      end
    end

    it "finds the type" do
      type_object = graphql_klass.query_klass

      aggregate_failures do
        expect(type_object.superclass).to eql(::HQ::GraphQL::Object)
        expect(type_object).to eql(described_class[Advisor])
        expect(type_object.fields.keys).to contain_exactly("customField")
        type_object.to_graphql
        expect(type_object.fields.keys).to contain_exactly("customField")
      end
    end

    it "finds the type when lookup is a string" do
      type_object = graphql_klass.query_klass
      expect(type_object).to eql(described_class["Advisor"])
    end

    it "raises an exception for unknown types" do
      expect { described_class[Advisor] }.to raise_error(described_class::Error)
    end
  end

end
