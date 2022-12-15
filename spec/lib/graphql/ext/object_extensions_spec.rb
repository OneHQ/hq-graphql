require 'rails_helper'

describe ::HQ::GraphQL::Ext::ObjectExtensions do

  describe ".with_model" do
    let(:hq_object) do
      Class.new(::GraphQL::Schema::Object) do
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
      hq_object.class_eval do
        with_model "Advisor"
      end

      expect(hq_object.fields.keys).to be_empty
      hq_object.lazy_load!
      expected = ["createdAt", "id", "name", "nickname", "organization", "organizationId", "updatedAt"]
      expect(hq_object.fields.keys).to contain_exactly(*expected)
    end

    it "doesn't override fields" do
      hq_object.class_eval do
        with_model "Advisor"
        field :name, Float, null: true
        field :organization, String, null: true
      end

      hq_object.lazy_load!
      aggregate_failures do
        expect(hq_object.fields["name"].type).to eq(::GraphQL::Types::Float)
        expect(hq_object.fields["organization"].type).to eq(::GraphQL::Types::String)
      end
    end

    describe ".remove_attributes" do
      it "removes an attribute" do
        hq_object.class_eval do
          remove_attributes :created_at, :id, :organization_id
          with_model "Advisor"
        end

        expect(hq_object.fields.keys).to be_empty
        hq_object.lazy_load!
        expected = ["name", "nickname", "organization", "updatedAt"]
        expect(hq_object.fields.keys).to contain_exactly(*expected)
      end

      it "raises an error when trying to remove a column that doesn't exist" do
        hq_object.class_eval do
          remove_attributes :doesnt_exist
          with_model "Advisor"
        end

        expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
      end

      it "raises an error when not connected to a model" do
        hq_object.class_eval do
          remove_attributes :created_at
        end

        expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
      end
    end

    describe ".remove_associations" do
      it "removes an association" do
        hq_object.class_eval do
          remove_associations :organization
          with_model "Advisor"
        end

        expect(hq_object.fields.keys).to be_empty
        hq_object.lazy_load!
        expected = ["createdAt", "id", "name", "nickname", "organizationId", "updatedAt"]
        expect(hq_object.fields.keys).to contain_exactly(*expected)
      end

      it "raises an error when trying to remove a column that doesn't exist" do
        hq_object.class_eval do
          remove_associations :doesnt_exist
          with_model "Advisor"
        end

        expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
      end

      it "raises an error when not connected to a model" do
        hq_object.class_eval do
          remove_associations :organization
        end

        expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
      end
    end

    context "with attributes and associations turned off" do
      it "doesn't have any fields by default" do
        hq_object.lazy_load!
        expect(hq_object.fields.keys).to be_empty
      end

      it "doesn't have any fields when disabling model attrs/associations" do
        hq_object.class_eval do
          with_model "Advisor", attributes: false, associations: false
        end
        hq_object.lazy_load!
        expect(hq_object.fields.keys).to be_empty
      end

      describe ".add_attributes" do
        it "adds attributes" do
          hq_object.class_eval do
            add_attributes :name
            with_model "Advisor", attributes: false, associations: false
          end

          expect(hq_object.fields.keys).to be_empty
          hq_object.lazy_load!
          expect(hq_object.fields.keys).to contain_exactly("name")
        end

        it "raises an error when adding an attribute that doesn't exist" do
          hq_object.class_eval do
            add_attributes :doesnt_exist
            with_model "Advisor", attributes: false, associations: false
          end

          expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
        end

        it "raises an error when not connected to a model" do
          hq_object.class_eval do
            add_attributes :name
          end

          expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
        end
      end

      describe ".add_associations" do
        it "adds associations" do
          hq_object.class_eval do
            add_associations :organization
            with_model "Advisor", attributes: false, associations: false
          end

          expect(hq_object.fields.keys).to be_empty
          hq_object.lazy_load!
          expect(hq_object.fields.keys).to contain_exactly("organization")
        end

        it "raises an error when adding an association that doesn't exist" do
          hq_object.class_eval do
            add_associations :doesnt_exist
            with_model "Advisor", attributes: false, associations: false
          end

          expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
        end

        it "raises an error when not connected to a model" do
          hq_object.class_eval do
            add_associations :organization
          end

          expect { hq_object.lazy_load! }.to raise_error(::GraphQL::Schema::Object::ActiveRecordError)
        end
      end
    end
  end

end
