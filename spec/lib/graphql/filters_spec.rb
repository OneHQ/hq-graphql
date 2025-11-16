require 'rails_helper'

describe ::HQ::GraphQL::Filters do
  include ActiveSupport::Testing::TimeHelpers
  let(:resource) do
    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "TestType"

      filter_field :count_plus_one, type: :integer, graphql_name: "countPlusOne", operations: [:GREATER_THAN, :LESS_THAN] do |scope, operation:, value:, table:, **|
        comparison = value.to_i
        expression = table[:count].plus(1)

        case operation.name
        when "GREATER_THAN"
          scope.where(expression.gt(comparison))
        when "LESS_THAN"
          scope.where(expression.lt(comparison))
        else
          scope
        end
      end

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
          nodes {
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

  it "generates enums of filterable fields" do
    resource::FilterFields.lazy_load!
    expect(resource::FilterFields.values.keys).to contain_exactly("id", "count", "amount", "isBool", "name", "createdDate", "createdAt", "updatedAt", "countPlusOne")

    resource::FilterColumnFields.lazy_load!
    expect(resource::FilterColumnFields.values.keys).to contain_exactly("id", "count", "amount", "isBool", "name", "createdDate", "createdAt", "updatedAt")
  end

  context "boolean field" do
    let!(:target) { TestType.create(is_bool: true) }

    it "filters test_types using WITH" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "t" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using WITH(out)" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "f" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using OR statement" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "t" }, { field: "isBool", operation: "WITH", value: "f", isOr: true }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 11
      expect(data.map { |d| d["id"] }).to contain_exactly(*(test_types + [target]).map(&:id))
    end

    it "only supports boolean values" do
      results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: "WITH", value: "str" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "isBool (type: boolean, operation: WITH, value: \"str\"): WITH operation only supports boolean values (t, f, true, false)"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "isBool", operation: operation.name, value: "t", arrayValues: ["t"] }] })
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
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using LESS_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "LESS_THAN", value: target.created_at.iso8601 }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using OR statement" do
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "GREATER_THAN", value: target.created_at.iso8601 }, { field: "createdAt", operation: "LESS_THAN", value: target.created_at.iso8601, isOr: true }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 11
      expect(data.map { |d| d["id"] }).to contain_exactly(*(test_types + [target]).map(&:id))
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
        results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: operation.name, value: target.created_at.iso8601, arrayValues: [] }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "createdAt (type: datetime, operation: #{operation.name}, value: \"#{target.created_at.iso8601}\"): only supports the following operations: GREATER_THAN, LESS_THAN, WITH"
      end
    end
  end

  context "date field advanced filters" do
    around do |example|
      travel_to(Time.zone.parse("2024-05-15 12:00:00 UTC")) { example.run }
    end

    let!(:today_record) { TestType.create(created_at: Time.zone.now) }
    let!(:last_week_record) { TestType.create(created_at: 7.days.ago) }
    let!(:last_month_record) { TestType.create(created_at: 1.month.ago.beginning_of_month + 2.days) }

    it "filters using GREATER_THAN with relative expressions" do
      expression = { kind: "RELATIVE", relative: { amount: 3, unit: "DAY", direction: "AGO" } }
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "GREATER_THAN", dateValue: expression }] })
      data = results["data"]["testTypes"]["nodes"]
      ids = data.map { |d| d["id"] }
      expect(ids).to include(today_record.id)
      expect(ids).not_to include(last_week_record.id, last_month_record.id)
    end

    it "filters using DATE_RANGE_BETWEEN with anchors" do
      expression = {
        from: { kind: "ANCHOR", anchored: { anchor: "START_OF", position: "LAST", period: "MONTH" } },
        to: { kind: "ANCHOR", anchored: { anchor: "END_OF", position: "LAST", period: "MONTH" } }
      }

      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "DATE_RANGE_BETWEEN", dateRangeValue: expression }] })
      data = results["data"]["testTypes"]["nodes"]
      ids = data.map { |d| d["id"] }
      expect(ids).to include(last_month_record.id)
      expect(ids).not_to include(today_record.id)
    end

    it "filters using NOT_EQUAL to exclude a specific day" do
      value = { kind: "ABSOLUTE", absolute: { value: Time.zone.now.iso8601 } }
      results = schema.execute(query, variables: { filters: [{ field: "createdAt", operation: "NOT_EQUAL", dateValue: value }] })
      data = results["data"]["testTypes"]["nodes"]
      ids = data.map { |d| d["id"] }
      expect(ids).not_to include(today_record.id)
      expect(ids).to include(last_week_record.id, last_month_record.id)
    end
  end

  context "numerical field" do
    let!(:target) { TestType.create(count: 11) }

    it "filters test_types using GREATER_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "10" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using LESS_THAN" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "LESS_THAN", value: "10" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using EQUAL" do
      target = test_types.sample
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "EQUAL", value: target.count.to_s }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "NOT_EQUAL", value: target.count.to_s }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types comparing columns" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "EQUAL", columnValue: "count" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 11
    end

    it "filters test_types using OR statement" do
      target_two = TestType.create(count: 12)
      results = schema.execute(query, variables: { filters: [
        { field: "count", operation: "EQUAL", value: target.count.to_s },
        { field: "count", operation: "EQUAL", value: target_two.count.to_s, isOr: true},
        { field: "count", operation: "IN", arrayValues: [target.count.to_s, target_two.count.to_s], isOr: true }
        ]})
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 2
      expect(data[0]["id"]).to eql(target_two.id)
      expect(data[1]["id"]).to eql(target.id)
    end


    it "only supports numerical values" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "Fizz" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "count (type: integer, operation: GREATER_THAN, value: \"Fizz\"): only supports numerical values"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::GREATER_THAN, described_class::Filter::LESS_THAN, described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::IN, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "count", operation: operation.name, value: "0" }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "count (type: integer, operation: #{operation.name}, value: \"0\"): only supports the following operations: GREATER_THAN, LESS_THAN, EQUAL, NOT_EQUAL, IN, WITH"
      end
    end
  end

  context "string field" do
    let!(:target) { TestType.create(name: "Unique Name") }

    it "filters test_types using EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "EQUAL", value: target.name }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "NOT_EQUAL", value: target.name }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using IN" do
      target_two = TestType.create(name: "Unique Name Two")
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "IN", arrayValues: [target.name, target_two.name] }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 2
      expect(data[0]["id"]).to eql(target_two.id)
      expect(data[1]["id"]).to eql(target.id)
    end

    it "filters test_types using LIKE" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "LIKE", value: "unique" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_LIKE" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "NOT_LIKE", value: "unique" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types comparing columns" do
      results = schema.execute(query, variables: { filters: [{ field: "name", operation: "EQUAL", columnValue: "name" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using OR statement" do
      target_two = TestType.create(name: "Unique Name Two")
      results = schema.execute(query, variables: { filters: [
        { field: "name", operation: "EQUAL", value: target.name },
        { field: "name", operation: "EQUAL", value: target_two.name, isOr: true},
        { field: "name", operation: "IN", arrayValues: [target.name, target_two.name], isOr: true }
        ]})
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 2
      expect(data[0]["id"]).to eql(target_two.id)
      expect(data[1]["id"]).to eql(target.id)
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::IN, described_class::Filter::LIKE, described_class::Filter::NOT_LIKE, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "name", operation: operation.name, value: "unique" }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "name (type: string, operation: #{operation.name}, value: \"unique\"): only supports the following operations: EQUAL, NOT_EQUAL, LIKE, NOT_LIKE, IN, WITH"
      end
    end
  end

  context "uuid" do
    let!(:target) { TestType.create }

    it "filters test_types using EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "id", operation: "EQUAL", value: target.id }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 1
      expect(data[0]["id"]).to eql(target.id)
    end

    it "filters test_types using NOT_EQUAL" do
      results = schema.execute(query, variables: { filters: [{ field: "id", operation: "NOT_EQUAL", value: target.id }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 10
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.map(&:id))
    end

    it "filters test_types using IN" do
      target_two = TestType.create
      results = schema.execute(query, variables: { filters: [{ field: "id", operation: "IN", arrayValues: [target.id, target_two.id] }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data[0]["id"]).to eql(target_two.id)
      expect(data[1]["id"]).to eql(target.id)
    end

    it "filters test_types using OR statement" do
      target_two = TestType.create
      results = schema.execute(query, variables: { filters: [
        { field: "id", operation: "EQUAL", value: target.id },
        { field: "id", operation: "EQUAL", value: target_two.id, isOr: true},
        { field: "id", operation: "IN", arrayValues: [target.id, target_two.id], isOr: true }
        ]})
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 2
      expect(data[0]["id"]).to eql(target_two.id)
      expect(data[1]["id"]).to eql(target.id)
    end

    it "only supports uuid values" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", value: "Fizz" }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to eq "count (type: integer, operation: GREATER_THAN, value: \"Fizz\"): only supports numerical values"
    end

    (described_class::Filter::OPERATIONS - [described_class::Filter::EQUAL, described_class::Filter::NOT_EQUAL, described_class::Filter::IN, described_class::Filter::WITH]).each do |operation|
      it "errors when using an unsupported operation: #{operation.name}" do
        results = schema.execute(query, variables: { filters: [{ field: "id", operation: operation.name, value: target.id }] })
        errors = results["errors"]
        expect(errors.length).to be 1
        expect(errors[0]["message"]).to eq "id (type: uuid, operation: #{operation.name}, value: \"#{target.id}\"): only supports the following operations: EQUAL, NOT_EQUAL, IN, WITH"
      end
    end
  end

  context "custom filter field" do
    it "filters using GREATER_THAN with a resolver proc" do
      results = schema.execute(query, variables: { filters: [{ field: "countPlusOne", operation: "GREATER_THAN", value: "5" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 5
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.select { |t| t.count > 4 }.map(&:id))
    end

    it "filters using LESS_THAN with a resolver proc" do
      results = schema.execute(query, variables: { filters: [{ field: "countPlusOne", operation: "LESS_THAN", value: "3" }] })
      data = results["data"]["testTypes"]["nodes"]
      expect(data.length).to be 2
      expect(data.map { |d| d["id"] }).to contain_exactly(*test_types.select { |t| t.count < 2 }.map(&:id))
    end

    it "rejects unsupported operations" do
      results = schema.execute(query, variables: { filters: [{ field: "countPlusOne", operation: "IN", arrayValues: ["1"] }] })
      errors = results["errors"]
      expect(errors.length).to be 1
      expect(errors[0]["message"]).to include("countPlusOne")
      expect(errors[0]["message"]).to include("only supports the following operations: GREATER_THAN, LESS_THAN")
    end

    it "cannot be referenced via columnValue" do
      results = schema.execute(query, variables: { filters: [{ field: "count", operation: "GREATER_THAN", columnValue: "countPlusOne" }] })
      errors = results["errors"]
      expect(errors.length).to be >= 1
      expect(errors.first["message"]).to include("countPlusOne")
    end
  end

  context "column_value enum selection" do
    let(:plain_resource) do
      Class.new do
        include ::HQ::GraphQL::Resource
        self.model_name = "TestType"
      end
    end

    it "reuses FilterFields when no custom filters exist" do
      argument = plain_resource.filter_input.arguments["columnValue"]
      expect(argument.type.graphql_name).to eq("#{plain_resource.graphql_name}QueryFilterFields")
    end

    it "uses FilterColumnFields when custom filters exist" do
      argument = resource.filter_input.arguments["columnValue"]
      expect(argument.type.graphql_name).to eq("#{resource.graphql_name}QueryFilterColumnFields")
    end
  end
end
