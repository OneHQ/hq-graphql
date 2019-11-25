# frozen_string_literal: true

require "rails_helper"

describe ::HQ::GraphQL::Comparator do
  let(:query) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "Query"

      field :field_to_remove, ::GraphQL::Types::Int, null: false

      field :field_with_changing_default_argument, ::GraphQL::Types::Int, null: false do
        argument :argument, ::GraphQL::Types::Int, required: false, default_value: 0
      end

      field :field_that_will_add_an_argument, ::GraphQL::Types::Int, null: true
    end
  end

  let(:schema) do
    Class.new(GraphQL::Schema) do
      query(Query)
    end
  end

  before(:each) do
    stub_const("Query", query)
  end

  describe "dumping a schema to a file" do
    before(:all) do
      @schema_directory = Rails.root.join("files")
    end

    after(:all) do
      ::FileUtils.rm_rf(@schema_directory) if ::File.directory?(@schema_directory)
    end

    let(:schema_filename) { "temp_schema.graphql" }

    it "should write the schema successfully to the file" do
      described_class.dump_schema_to_file(directory: @schema_directory, filename: schema_filename, schema: schema)
      file_contents = ::File.read(::File.join(@schema_directory, schema_filename))
      expect(file_contents).to eq(schema.to_definition)
    end
  end

  describe "Comparing two schemas" do
    context "when the criticality is not valid" do
      it "should raise an error" do
        expect { described_class.compare(schema, schema, criticality: :invalid_criticality) }.to raise_error(::ArgumentError, /Invalid criticality. Possible values are #{described_class::CRITICALITY.keys.join(", ")}/i)
      end
    end

    context "when the schemas are identical" do
      it "should return nil" do
        result = described_class.compare(schema, schema, criticality: :non_breaking)
        expect(result).to be_nil
      end
    end

    context "when there are differences between the schemas" do
      before(:each) do
        stub_const("NewQuery", new_query)
      end

      let(:new_query) do
        Class.new(::HQ::GraphQL::Object) do
          graphql_name "Query"

          # Breaking change: FieldRemoved (field_to_remove was removed)

          # Dangerous change: FieldArgumentDefaultChanged (0 -> 1)
          field :field_with_changing_default_argument, ::GraphQL::Types::Int, null: false do
            argument :argument, ::GraphQL::Types::Int, required: false, default_value: 1
          end

          # Non-breaking change: Adding a non-required argument
          field :field_that_will_add_an_argument, ::GraphQL::Types::Int, null: true do
            argument :argument, ::GraphQL::Types::Int, required: false
          end
        end
      end

      let(:new_schema) do
        Class.new(GraphQL::Schema) do
          query(NewQuery)
        end
      end

      context "when the criticality is set to non-breaking" do
        it "should list all changes" do
          result = described_class.compare(schema, new_schema, criticality: :non_breaking)
          aggregate_failures do
            expect(result[:breaking]).not_to be_nil
            expect(result[:dangerous]).not_to be_nil
            expect(result[:non_breaking]).not_to be_nil
          end

          expect(result[:breaking].count).to eq(1)
          expect(result[:breaking].first.criticality.reason).to match(/Removing a field/i)

          expect(result[:dangerous].count).to eq(1)
          expect(result[:dangerous].first.criticality.reason).to match(/Changing the default value for an argument/i)

          expect(result[:non_breaking].count).to eq(1)
          expect(result[:non_breaking].first.field.name).to eq("fieldThatWillAddAnArgument")
        end
      end

      context "when the criticality is set to dangerous" do
        it "should list dangerous and breaking changes" do
          result = described_class.compare(schema, new_schema, criticality: :dangerous)
          expect(result[:breaking]).not_to be_nil
          expect(result[:dangerous]).not_to be_nil
          expect(result[:breaking].count).to eq(1)
          expect(result[:dangerous].count).to eq(1)
        end

        it "should not list non-breaking changes" do
          result = described_class.compare(schema, new_schema, criticality: :dangerous)
          expect(result[:non_breaking]).to be_nil
        end
      end

      context "when the criticality is set to breaking" do
        it "should list the breaking changes" do
          result = described_class.compare(schema, new_schema)
          expect(result[:breaking]).not_to be_nil
          expect(result[:breaking].count).to eq(1)
          expect(result[:breaking].first.criticality.reason).to match(/Removing a field is a breaking change/i)
        end

        it "should not list dangerous or non-breaking changes" do
          result = described_class.compare(schema, new_schema)
          expect(result[:dangerous]).to be_nil
          expect(result[:non_breaking]).to be_nil
        end
      end
    end
  end
end
