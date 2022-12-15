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

  let!(:test_types) { 10.times.map { |i| TestType.create(created_at: 1.year.ago, count: i) } }

  let(:query) { <<-GRAPHQL
      query findTestTypes($before: String, $after: String, $first: Int, $last: Int, $sortOrder: SortOrder) {
        testTypes(before: $before, after: $after, first: $first, last: $last, sortOrder: $sortOrder) {
          cursors
          totalCount
          nodes {
            id
          }
          testTypes{
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
  context "total elements" do
    it "totalCount equal to testTypes size" do
      results = schema.execute(query, variables: { first: 2, sortOrder: "ASC" })
      advisors = results["data"]["testTypes"]["testTypes"]
      totalCount = results["data"]["testTypes"]["totalCount"]
      expect(advisors.length).to eq totalCount
    end
  end
end
