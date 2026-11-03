require "rails_helper"

describe "Root query initialValues" do
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

  # A day apart, oldest first, so sorting by createdAt ASC gives test_types' order.
  let!(:test_types) { 10.times.map { |i| TestType.create(created_at: (10 - i).days.ago, count: i) } }

  let(:query) do
    <<-GRAPHQL
      query findTestTypes($first: Int, $after: String, $initialValues: [ID], $filters: [TestTypeQueryFilterInput!]) {
        testTypes(first: $first, after: $after, sortBy: CreatedAt, sortOrder: ASC, initialValues: $initialValues, filters: $filters) {
          totalCount
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
          }
        }
      }
    GRAPHQL
  end

  before(:each) do
    resource
    stub_const("RootQuery", root_query)
  end

  def fetch(**variables)
    results = schema.execute(query, variables: variables)
    expect(results["errors"]).to be_nil
    results["data"]["testTypes"]
  end

  def ids_of(page)
    page["nodes"].pluck("id")
  end

  it "keeps the natural order without initialValues" do
    expect(ids_of(fetch(first: 3))).to eq test_types.first(3).map(&:id)
  end

  it "ignores an empty list" do
    expect(ids_of(fetch(first: 3, initialValues: []))).to eq test_types.first(3).map(&:id)
  end

  it "puts the initial records on the first page, in the list's order, followed by the rest" do
    initial = [test_types[8], test_types[5]]

    page = fetch(first: 4, initialValues: initial.map(&:id))

    expect(ids_of(page)).to eq [test_types[5], test_types[8], test_types[0], test_types[1]].map(&:id)
    expect(page["totalCount"]).to eq 10
  end

  it "does not repeat the initial records on the next pages" do
    initial_values = [test_types[8].id, test_types[5].id]

    pages = []
    after = nil
    loop do
      page = fetch(first: 4, after: after, initialValues: initial_values)
      pages << ids_of(page)
      break unless page["pageInfo"]["hasNextPage"]

      after = page["pageInfo"]["endCursor"]
    end

    expect(pages.size).to eq 3
    expect(pages.flatten).to eq(initial_values.reverse + (test_types.map(&:id) - initial_values))
  end

  it "only fills the first page when there are more initial values than fit on it" do
    initial = test_types.last(3)

    expect(ids_of(fetch(first: 2, initialValues: initial.map(&:id)))).to eq initial.first(2).map(&:id)
  end

  it "does not bring in records the filters leave out" do
    filtered_out = test_types[1]
    kept = test_types[9]

    page = fetch(
      first: 3,
      initialValues: [filtered_out.id, kept.id],
      filters: [{ field: "count", operation: "GREATER_THAN", value: "4" }]
    )

    expect(ids_of(page)).to eq [kept, test_types[5], test_types[6]].map(&:id)
  end

  describe "values that match no record" do
    it "drops them without an error" do
      values = [SecureRandom.uuid, "not-a-uuid", 123, "99999999999999999999", nil, test_types[3].id]

      page = fetch(first: 2, initialValues: values)

      expect(ids_of(page)).to eq [test_types[3], test_types[0]].map(&:id)
    end

    it "keeps the natural order when none of them match" do
      page = fetch(first: 3, initialValues: [SecureRandom.uuid, "not-a-uuid", 123])

      expect(ids_of(page)).to eq test_types.first(3).map(&:id)
    end
  end

  it "takes a value sent twice only once" do
    page = fetch(first: 2, initialValues: [test_types[3].id, test_types[3].id])

    expect(ids_of(page)).to eq [test_types[3], test_types[0]].map(&:id)
  end
end
