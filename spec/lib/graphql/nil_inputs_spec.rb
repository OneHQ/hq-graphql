require 'rails_helper'

describe ::HQ::GraphQL::NilInputs do

  describe ".[]" do
    let(:graphql_klass) do
      Class.new do
        include ::HQ::GraphQL::Resource

        self.model_name = "Advisor"

        input(attributes: false, associations: false) do
          argument :customField, String, "Header for the post", required: true
        end
      end
    end

    it "finds the type" do
      nil_input_object = graphql_klass.nil_input_klass

      aggregate_failures do
        expect(nil_input_object.superclass).to eql(::GraphQL::Schema::InputObject)
        expect(nil_input_object).to eql(described_class[Advisor])
        expect(nil_input_object.arguments.keys).to contain_exactly("customField")
        nil_input_object.lazy_load!
        expect(nil_input_object.arguments.keys).to contain_exactly("customField", "X")
      end
    end

    it "finds the type when lookup is a string" do
      nil_input_object = graphql_klass.nil_input_klass
      expect(nil_input_object).to eql(described_class["Advisor"])
    end

    it "raises an exception for unknown types" do
      expect { described_class[Advisor] }.to raise_error(described_class::Error)
    end
  end

end
