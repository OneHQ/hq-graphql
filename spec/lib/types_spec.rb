require 'rails_helper'

describe ::HQ::GraphQL::Types do

  describe ".[]" do
    before(:each) do
      described_class.reset!
    end

    after(:each) do
      described_class.reset!
    end

    it "generates a new class with columns & associations" do
      # Unique Classes
      allow(::HQ::GraphQL).to receive(:model_to_graphql_type) { -> (model_class) { "#{model_class.name.demodulize}TypeTest" } }

      advisor_klass = described_class[Advisor]
      user_klass = described_class[User]
      advisor_user_fields = ["id", "organizationId", "name", "createdAt", "updatedAt", "organization"]

      #### Advisor Schema ####
      expect(advisor_klass.name).to eql(::HQ::GraphQL.graphql_type_from_model(Advisor))
      expect(advisor_klass.fields.keys).to be_empty
      ### Build GraphQL schema
      advisor_klass.to_graphql
      expect(advisor_klass.fields.keys).to contain_exactly(*advisor_user_fields)

      #### User Schema ####
      expect(user_klass.name).to eql(::HQ::GraphQL.graphql_type_from_model(User))
      expect(user_klass.fields.keys).to be_empty
      user_klass.to_graphql
      expect(user_klass.fields.keys).to contain_exactly(*advisor_user_fields)

      organization_klass = ::HQ::GraphQL.graphql_type_from_model(Organization).constantize
      expect(organization_klass.fields.keys).to be_empty
      organization_klass.to_graphql
      organization_fields = ["id", "name", "createdAt", "updatedAt", "users"]
      expect(organization_klass.fields.keys).to contain_exactly(*organization_fields)
    end

    it "users the existing class if one exists" do
      allow(::HQ::GraphQL).to receive(:model_to_graphql_type) { -> (model_class) { "#{model_class.name.demodulize}TypeTestTwo" } }

      klass = Class.new(::HQ::GraphQL::Object) do
        graphql_name "TestQuery"

        field :custom_field, String, null: false
      end
      advisor_klass = stub_const(::HQ::GraphQL.graphql_type_from_model(Advisor), klass)

      expect(advisor_klass).to eql(described_class[Advisor])
      expect(advisor_klass.fields.keys).to contain_exactly("customField")
      advisor_klass.to_graphql
      expect(advisor_klass.fields.keys).to contain_exactly("customField")
    end

  end

end
