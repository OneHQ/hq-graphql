require 'rails_helper'

describe ::HQ::GraphQL::ObjectAssociation do
  let!(:organization_resource) do
    Class.new do
      include ::HQ::GraphQL::Resource

      self.model_name = "Organization"

      root_query
      query do
        has_many :custom_association, -> { where(inactive: nil) }, class_name: "User" do
          argument :name, String, required: false

          scope do |name: nil|
            if name
              User.where(name: name)
            end
          end
        end
      end
    end
  end

  let!(:user_resource) do
    Class.new do
      include ::HQ::GraphQL::Resource

      self.model_name = "User"
    end
  end

  let(:root_query) do
    Class.new(::HQ::GraphQL::RootQuery)
  end


  let(:schema) do
    Class.new(GraphQL::Schema) do
      query(RootQuery)
      use(::GraphQL::Batch)
    end
  end

  before(:each) do
    allow(::HQ::GraphQL.config).to receive(:use_experimental_associations) { true }
    stub_const("RootQuery", root_query)
    schema.to_graphql
  end

  context "meta data" do
    it "adds a custom association field" do
      expect(organization_resource.query_object.fields.keys).to include("customAssociation")
    end
  end

  context "execution" do
    let(:organization) { ::FactoryBot.create(:organization) }
    let!(:user1) { ::FactoryBot.create(:user, organization: organization) }
    let!(:user2) { ::FactoryBot.create(:user, organization: organization, inactive: true) }
    let!(:user3) { ::FactoryBot.create(:user, organization: organization) }

    let(:find_organization) do
      <<~GRAPHQL
        query FindOrganization($id: ID!, $userName: String) {
          organization(id: $id) {
            id
            customAssociation(name: $userName) {
              id
              name
            }
          }
        }
      GRAPHQL
    end

    it "finds active users" do
      results = schema.execute(find_organization, variables: { id: organization.id })
      data = results["data"]["organization"]

      expected = {
        id: organization.id,
        customAssociation: [user3, user1].map { |u| { id: u.id, name: u.name } }
      }
      expect(data.deep_symbolize_keys).to eql(expected)
    end

    it "finds user with a name scope" do
      results = schema.execute(find_organization, variables: { id: organization.id, userName: user1.name })
      data = results["data"]["organization"]

      expected = {
        id: organization.id,
        customAssociation: [{ id: user1.id, name: user1.name }]
      }
      expect(data.deep_symbolize_keys).to eql(expected)
    end
  end
end
