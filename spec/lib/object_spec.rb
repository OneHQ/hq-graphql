require 'rails_helper'

describe ::HQ::GraphQL::Object do

  describe ".lazy_load" do
    let(:lazy_load_class) do
      Class.new(described_class) do
        graphql_name "LazyLoadQuery"

        @counter = 0

        lazy_load do
          @counter += 1
        end

        def self.counter
          @counter
        end
      end
    end

    it "lazy loads once" do
      # First time it works
      expect { lazy_load_class.to_graphql }.to change  { lazy_load_class.counter }.by(1)
      # Second time it does nothing
      expect { lazy_load_class.to_graphql }.to change  { lazy_load_class.counter }.by(0)
    end
  end

  describe ".with_model" do
    let(:hql_object_klass) do
      Class.new(described_class) do
        graphql_name "TestQuery"
      end
    end

    it "adds everything by default" do
      hql_object_klass.class_eval do
        with_model "Advisor"
      end

      expect(hql_object_klass.fields.keys).to be_empty
      hql_object_klass.to_graphql
      expected = ["createdAt", "id", "name", "organization", "organizationId", "updatedAt"]
      expect(hql_object_klass.fields.keys).to contain_exactly(*expected)
    end

    it "removes an attribute" do
      hql_object_klass.class_eval do
        remove_attrs :created_at, :id, :organization_id
        with_model "Advisor"
      end

      expect(hql_object_klass.fields.keys).to be_empty
      hql_object_klass.to_graphql
      expected = ["name", "organization", "updatedAt"]
      expect(hql_object_klass.fields.keys).to contain_exactly(*expected)
    end

    it "removes an association" do
      hql_object_klass.class_eval do
        remove_associations :organization, :doesntexist
        with_model "Advisor"
      end

      expect(hql_object_klass.fields.keys).to be_empty
      hql_object_klass.to_graphql
      expected = ["createdAt", "id", "name", "organizationId", "updatedAt"]
      expect(hql_object_klass.fields.keys).to contain_exactly(*expected)
    end

    context "with attributes and associations turned off" do
      it "doesn't have any fields by default" do
        hql_object_klass.to_graphql
        expect(hql_object_klass.fields.keys).to be_empty
      end

      it "doesn't have any fields when disabling model attrs/associations" do
        hql_object_klass.class_eval do
          with_model "Advisor", attributes: false, associations: false
        end
        hql_object_klass.to_graphql
        expect(hql_object_klass.fields.keys).to be_empty
      end

      it "blows up when adding an attribute to an object without a model" do
        hql_object_klass.class_eval do
          add_attr :name
        end

        expect { hql_object_klass.to_graphql }.to raise_error(described_class::Error)
      end

      it "blows up when adding an attribute that doesn't exist" do
        hql_object_klass.class_eval do
          add_attr :doesnt_exist

          with_model "Advisor", attributes: false, associations: false
        end

        expect { hql_object_klass.to_graphql }.to raise_error(described_class::Error)
      end

      it "adds attributes once connected to a model" do
        hql_object_klass.class_eval do
          # Order shouldn't matter....but let's test it anyway

          # First
          add_attr :name

          # Second
          with_model "Advisor", attributes: false, associations: false
        end

        expect(hql_object_klass.fields.keys).to be_empty
        hql_object_klass.to_graphql
        expect(hql_object_klass.fields.keys).to contain_exactly("name")
      end

      it "blows up when adding an association to an object without a model" do
        hql_object_klass.class_eval do
          add_association :organization
        end

        expect { hql_object_klass.to_graphql }.to raise_error(described_class::Error)
      end

      it "blows up when adding an association that doesn't exist" do
        hql_object_klass.class_eval do
          add_association :doesnt_exist

          with_model "Advisor", attributes: false, associations: false
        end

        expect { hql_object_klass.to_graphql }.to raise_error(described_class::Error)
      end

      it "adds associations once connected to a model" do
        hql_object_klass.class_eval do
          # Order shouldn't matter....but let's test it anyway

          # First
          add_association :organization

          # Second
          with_model "Advisor", attributes: false, associations: false
        end

        expect(hql_object_klass.fields.keys).to be_empty
        hql_object_klass.to_graphql
        expect(hql_object_klass.fields.keys).to contain_exactly("organization")
      end

    end

    context "with a schema" do
      let(:user_1) { FactoryBot.create(:user) }
      let(:user_2) { FactoryBot.create(:user, organization: user_1.organization) }

      before(:each) do
        user_1
        user_2
      end

      it "executes graphql" do
        query_str = <<-GRAPHQ
          query {
            users {
              name
              organizationId

              organization {
                name
              }
            }
          }
        GRAPHQ

        result = ::Schema.execute(query_str)

        aggregate_failures do
          user_1_data, user_2_data = result["data"]["users"]
          # User 1
          expect(user_1_data["name"]).to eql(user_1.name)
          expect(user_1_data["organizationId"]).to eql(user_1.organization_id)
          expect(user_1_data["organization"]["name"]).to eql(user_1.organization.name)

          # User 2
          expect(user_2_data["name"]).to eql(user_2.name)
          expect(user_2_data["organizationId"]).to eql(user_2.organization_id)
          expect(user_2_data["organization"]["name"]).to eql(user_2.organization.name)
        end
      end
    end

  end

end
