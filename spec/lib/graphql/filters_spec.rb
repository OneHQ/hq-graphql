require 'rails_helper'

describe ::HQ::GraphQL::Filters do
  let(:resource) do
    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "TestType"

      root_query
    end
  end

  let(:root_query) do
    Class.new(::HQ::GraphQL::RootQuery)
  end

  let(:schema) do
    Class.new(::GraphQL::Schema) do
      query(::RootQuery)
      use(::GraphQL::Batch)
    end
  end

  let!(:test_types) { 10.times.map { |i| TestType.create(created_at: 1.year.ago, count: i) } }

  let(:query) { <<-GRAPHQL
      query findTestTypes($filters: [TestTypeQueryFilterInput!]) {
        testTypes(filters: $filters) {
          testTypes {
            id
          }
        }
      }
    GRAPHQL
  }

  before(:each) do
    resource
    stub_const("RootQuery", root_query)
  end

  it "generates an enum of filterable fields" do
    resource::FilterFields.lazy_load!
    expect(resource::FilterFields.values.keys).to contain_exactly("id", "count", "amount", "isBool", "name", "createdDate", "createdAt", "updatedAt")
  end

  context "boolean field" do
    let!(:target) { TestType.create(is_bool: true) }

    it "filters test_types using WITH" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "t" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using WITH(out)" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "f" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "only supports boolean values" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "str" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "isBool (type: boolean, operation: WITH, value: \"str\"): WITH operation only supports boolean values (t, f, true, false)"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: operation.name, value: "t" }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "isBool (type: boolean, operation: #{operation.name}, value: \"t\"): only supports the following operations: WITH"
      end
    end
  end

  context "date field" do
    let!(:target) { TestType.create }

    it "filters test_types using GREATER_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "GREATER_THAN", value: target.created_at.iso8601 }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using LESS_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "LESS_THAN", value: target.created_at.iso8601 }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "only supports iso8601 values" do
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "GREATER_THAN", value: target.created_at.to_s }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      today = Date.today
      expect(errors[0]["message"]).to eq "createdAt (type: datetime, operation: GREATER_THAN, value: \"#{target.created_at.to_s}\"): only supports ISO8601 values (\"#{today.iso8601}\", \"#{today.to_datetime.iso8601}\")"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::GREATER_THAN, described_class::Filter::LESS_THAN, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: operation.name, value: target.created_at.iso8601 }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "createdAt (type: datetime, operation: #{operation.name}, value: \"#{target.created_at.iso8601}\"): only supports the following operations: GREATER_THAN, LESS_THAN, WITH"
      end
    end
  end

  context "numerical field" do
    let!(:target) { TestType.create(count: 11) }

    it "filters test_types using GREATER_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "10" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using LESS_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "LESS_THAN", value: "10" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using EQUAL" do
      target = test_types.sample
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "EQUAL", value: target.count.to_s }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "NOT_EQUAL", value: target.count.to_s }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "only supports numerical values" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "Fizz" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "count (type: integer, operation: GREATER_THAN, value: \"Fizz\"): only supports numerical values"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::GREATER_THAN, described_class::Filter::LESS_THAN, described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "count", operation: operation.name, value: "0" }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "count (type: integer, operation: #{operation.name}, value: \"0\"): only supports the following operations: GREATER_THAN, LESS_THAN, EQUAL, NOT_EQUAL, WITH"
      end
    end
  end

  context "string field" do
    let!(:target) { TestType.create(name: "Unique Name") }

    it "filters test_types using EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "EQUAL", value: target.name }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "NOT_EQUAL", value: target.name }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using LIKE" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "LIKE", value: "unique" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_LIKE" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "NOT_LIKE", value: "unique" }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::LIKE, described_class::Filter::NOT_LIKE, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "name", operation: operation.name, value: "unique" }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "name (type: string, operation: #{operation.name}, value: \"unique\"): only supports the following operations: EQUAL, NOT_EQUAL, LIKE, NOT_LIKE, WITH"
      end
    end
  end

  context "uuid" do
    let!(:target) { TestType.create }

    it "filters test_types using EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "id", operation: "EQUAL", value: target.id }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "id", operation: "NOT_EQUAL", value: target.id }] })
      data = results["data"]["testTypes"]["testTypes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "only supports uuid values" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "Fizz" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "count (type: integer, operation: GREATER_THAN, value: \"Fizz\"): only supports numerical values"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "id", operation: operation.name, value: target.id }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "id (type: uuid, operation: #{operation.name}, value: \"#{target.id}\"): only supports the following operations: EQUAL, NOT_EQUAL, WITH"
      end
    end
  end
end
