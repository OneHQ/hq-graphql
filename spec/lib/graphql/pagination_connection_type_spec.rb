require 'rails_helper'

describe ::HQ::GraphQL::PaginationConnectionType do
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

  let!(:test_types) { 252.times.map { |i| TestType.create(created_at: 1.year.ago, count: i) } }

  let(:query) { <<-GRAPHQL
      query findTestTypes($before: String, $after: String, $first: Int, $last: Int, $sortOrder: SortOrder) {
        testTypes(before: $before, after: $after, first: $first, last: $last, sortOrder: $sortOrder) {
          cursors
          totalCount
          nodes {
            id
          }
          edges {
            cursor
            node{
              id
            }
          }
        }
      }
    GRAPHQL
  }

  before(:each) do
    resource
    stub_const("RootQuery", root_query)
  end

  context "first + last" do
    it "first 1" do
      results = schema.execute(query, variables: { first: 1, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.first(1).map(&:id)
    end

    it "first 2" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.first(2).map(&:id)
    end
    it "first 2, with totalCount > limit_max" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      data = results["data"]["testTypes"]["nodes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(data.length).to be 2
      expect(totalCount).to be 252
    end
    it "last 1" do
      results = schema.execute(query, variables: { last: 1, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.last(1).map(&:id)
    end

    it "last 2" do
      results = schema.execute(query, variables: { last: 2, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.last(2).map(&:id)
    end

    it "last 2, with totalCount > limit_max" do
      results = schema.execute(query, variables: { last: 2, sortOrder: "ASC" })
      data = results["data"]["testTypes"]["nodes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(data.length).to be 2
      expect(totalCount).to be 252
    end
  end

  context "after" do
    it "first 2, after 2 element cursor" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      edges = results["data"]["testTypes"]["edges"]
      cursor = edges.last["cursor"]
      results = schema.execute(query, variables: { first: 2, after: cursor, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.drop(2).first(2).map(&:id)
    end
    it "last 2, after 2 element cursor" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      edges = results["data"]["testTypes"]["edges"]
      cursor = edges.last["cursor"]
      results = schema.execute(query, variables: { last: 2, after: cursor, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.last(2).map(&:id)
    end
  end
  context "before" do
    it "first 2, before 2 element cursor" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      edges = results["data"]["testTypes"]["edges"]
      cursor = edges.last["cursor"]
      results = schema.execute(query, variables: { first: 2, before: cursor, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.first(1).map(&:id)
    end
    it "last 2, before 2 element cursor" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      edges = results["data"]["testTypes"]["edges"]
      cursor = edges.last["cursor"]
      results = schema.execute(query, variables: { first: 2, before: cursor, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["nodes"].pluck("id")
      expect(advisors).to eq test_types.first(1).map(&:id)
    end
  end

  context "first + last" do
    it "page size == 250 with first > 250" do
      results = schema.execute(query, variables: { first: 1000, sortOrder: "ASC" })
      data = results["data"]["testTypes"]["nodes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(data.length).to be 250
      expect(totalCount).to be 252
    end
    it "page size == 250 with last > 250" do
      results = schema.execute(query, variables: { last: 1000, sortOrder: "ASC" })
      data = results["data"]["testTypes"]["nodes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(data.length).to be 250
      expect(totalCount).to be 252
    end
    it "page size == 250 without first and last" do
      results = schema.execute(query, variables: { first: 1000, sortOrder: "ASC" })
      data = results["data"]["testTypes"]["nodes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(data.length).to be 250
      expect(totalCount).to be 252
    end
  end
end
