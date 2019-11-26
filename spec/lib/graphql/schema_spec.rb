# frozen_string_literal: true

require "rails_helper"

describe ::HQ::GraphQL::Schema do
  let(:query) do
    Class.new(::HQ::GraphQL::Object) do
      graphql_name "Query"

      field :field, ::GraphQL::Types::Int, null: false
    end
  end

  let(:schema) do
    Class.new(::HQ::GraphQL::Schema) do
      query(Query)

      class << self
        def dump_directory
          Rails.root.join("files")
        end

        def dump_filename
          "temp_schema.graphql"
        end
      end
    end
  end

  before(:each) do
    stub_const("Query", query)
  end

  after(:all) do
    ::FileUtils.rm_rf(Rails.root.join("files")) if ::File.directory?(Rails.root.join("files"))
  end

  it "should write the schema successfully to the file" do
    schema.dump
    file_contents = ::File.read(::File.join(schema.dump_directory, schema.dump_filename))
    expect(file_contents).to eq(schema.to_definition)
  end
end
