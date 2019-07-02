require 'rails_helper'

describe ::HQ::GraphQL::InputObject do

  describe ".with_model" do
    let(:hq_input_object) do
      Class.new(described_class) do
        graphql_name "TestQuery"
      end
    end

    let(:organization_type) do
      Class.new do
        include ::HQ::GraphQL::Resource

        self.model_name = "Organization"
      end
    end

    before(:each) do
      organization_type
    end

    it "adds everything by default" do
      hq_input_object.class_eval do
        with_model "Advisor"
      end

      expect(hq_input_object.arguments.keys).to be_empty
      hq_input_object.graphql_definition
      expected = ["createdAt", "id", "name", "organizationId", "updatedAt", "X"]
      expect(hq_input_object.arguments.keys).to contain_exactly(*expected)
    end

    describe ".remove_attributes" do
      it "removes an attribute" do
        hq_input_object.class_eval do
          remove_attributes :created_at, :id, :organization_id
          with_model "Advisor"
        end

        expect(hq_input_object.arguments.keys).to be_empty
        hq_input_object.graphql_definition
        expected = ["name", "updatedAt", "X"]
        expect(hq_input_object.arguments.keys).to contain_exactly(*expected)
      end

      it "raises an error when trying to remove a column that doesn't exist" do
        hq_input_object.class_eval do
          remove_attributes :doesnt_exist
          with_model "Advisor"
        end

        expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
      end

      it "raises an error when not connected to a model" do
        hq_input_object.class_eval do
          remove_attributes :created_at
        end

        expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
      end
    end

    describe ".remove_associations" do
      it "removes an association" do
        hq_input_object.class_eval do
          remove_associations :organization
          with_model "Advisor"
        end

        expect(hq_input_object.arguments.keys).to be_empty
        hq_input_object.graphql_definition
        expected = ["createdAt", "id", "name", "organizationId", "updatedAt", "X"]
        expect(hq_input_object.arguments.keys).to contain_exactly(*expected)
      end

      it "raises an error when trying to remove a column that doesn't exist" do
        hq_input_object.class_eval do
          remove_associations :doesnt_exist
          with_model "Advisor"
        end

        expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
      end

      it "raises an error when not connected to a model" do
        hq_input_object.class_eval do
          remove_associations :organization
        end

        expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
      end
    end

    context "with attributes and associations turned off" do
      it "doesn't have any arguments by default" do
        hq_input_object.graphql_definition
        expect(hq_input_object.arguments.keys).to be_empty
      end

      it "doesn't have any arguments when disabling model attrs/associations" do
        hq_input_object.class_eval do
          with_model "Advisor", attributes: false, associations: false
        end
        hq_input_object.graphql_definition
        expect(hq_input_object.arguments.keys).to contain_exactly("X")
      end

      describe ".add_attributes" do
        it "adds attributes" do
          hq_input_object.class_eval do
            add_attributes :name
            with_model "Advisor", attributes: false, associations: false
          end

          expect(hq_input_object.arguments.keys).to be_empty
          hq_input_object.graphql_definition
          expect(hq_input_object.arguments.keys).to contain_exactly("name", "X")
        end

        it "raises an error when adding an attribute that doesn't exist" do
          hq_input_object.class_eval do
            add_attributes :doesnt_exist
            with_model "Advisor", attributes: false, associations: false
          end

          expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
        end

        it "raises an error when not connected to a model" do
          hq_input_object.class_eval do
            add_attributes :name
          end

          expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
        end
      end

      describe ".add_associations" do
        it "adds associations" do
          hq_input_object.class_eval do
            add_associations :organization
            with_model "Advisor", attributes: false, associations: false
          end

          expect(hq_input_object.arguments.keys).to be_empty
          hq_input_object.graphql_definition
          expect(hq_input_object.arguments.keys).to contain_exactly("organization", "X")
        end

        it "raises an error when adding an association that doesn't exist" do
          hq_input_object.class_eval do
            add_associations :doesnt_exist
            with_model "Advisor", attributes: false, associations: false
          end

          expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
        end

        it "raises an error when not connected to a model" do
          hq_input_object.class_eval do
            add_associations :organization
          end

          expect { hq_input_object.graphql_definition }.to raise_error(described_class::Error)
        end
      end
    end
  end

end
