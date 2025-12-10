require "rails_helper"

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

    let(:type_object) { graphql_klass.query_object }

    before(:each) do
      graphql_klass
    end

    it "finds the type" do
      aggregate_failures do
        expect(type_object.superclass).to eql(::GraphQL::Schema::Object)
        expect(type_object).to eql(described_class[Advisor])
        expect(type_object.fields.keys).to contain_exactly("customField")
        type_object.lazy_load!
        expect(type_object.fields.keys).to contain_exactly("customField")
      end
    end

    it "finds the type when lookup is a string" do
      expect(type_object).to eql(described_class["Advisor"])
    end

    it "raises an exception for unknown types" do
      expect { described_class[Organization] }.to raise_error(described_class::Error)
    end

    it "works with sti" do
      sti_resource = Class.new do
        include ::HQ::GraphQL::Resource
        self.model_name = "Agent"
      end
      expect(sti_resource.query_object).to eql(described_class["Agent"])
    end

    it "falls back to the base class" do
      expect(type_object).to eql(described_class["Agent"])
    end
  end

  describe ".type_from_column" do
    context "UUID" do
      it "matches uuid" do
        expect(type_from_column("id")).to eq ::HQ::GraphQL::Types::UUID
      end
    end

    context "Object" do
      it "matches json" do
        expect(type_from_column("data_json")).to eq ::GraphQL::Types::JSON
      end

      it "matches jsonb" do
        expect(type_from_column("data_jsonb")).to eq ::GraphQL::Types::JSON
      end
    end

    context "Int" do
      it "matches integer" do
        expect(type_from_column("count")).to eq ::GraphQL::Types::Int
      end
    end

    context "Float" do
      it "matches decimal" do
        expect(type_from_column("amount")).to eq ::GraphQL::Types::Float
      end
    end

    context "Boolean" do
      it "matches boolean" do
        expect(type_from_column("is_bool")).to eq ::GraphQL::Types::Boolean
      end
    end

    context "String" do
      it "matches string" do
        expect(type_from_column("name")).to eq ::GraphQL::Types::String
      end
    end

    context "DateTime" do
      it "matches iso datetime" do
        expect(type_from_column("created_at")).to eq ::GraphQL::Types::ISO8601DateTime
      end
    end

    context "Date" do
      it "matches iso date" do
        expect(type_from_column("created_date")).to eq ::Types::DateType
      end
    end

    def type_from_column(name)
      described_class.type_from_column(TestType.columns_hash[name])
    end
  end

end
