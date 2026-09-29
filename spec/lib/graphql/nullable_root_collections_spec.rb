require "rails_helper"

# `nullable_root_collections` relaxes ROOT collection fields, so a host that
# denies one has somewhere to put the denial.
#
# Null rather than an empty collection, deliberately: `[]` asserts that there
# are none, which is a different fact from "not yours to see". Conflating them
# makes a client state the wrong one -- and it would contradict
# `nullable_associations`, which already draws that line for associations.
describe "HQ::GraphQL.nullable_root_collections?" do
  def build_resource!
    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "Advisor"
      root_query
    end
  end

  def root_field_type(name)
    query = Class.new(::HQ::GraphQL::RootQuery)
    stub_const("RootQuery", query)
    ::HQ::GraphQL.load_types!
    query.lazy_load!
    query.fields[name].type.to_type_signature
  end

  before(:each) do
    ::HQ::GraphQL.reset!
    build_resource!
  end

  after(:each) { ::HQ::GraphQL.reset! }

  context "off (the default)" do
    it "is disabled unless the host opts in" do
      expect(::HQ::GraphQL.nullable_root_collections?).to be false
    end

    it "emits a root collection as non-null" do
      expect(root_field_type("advisors")).to eq("AdvisorConnection!")
    end
  end

  context "on" do
    before(:each) do
      allow(::HQ::GraphQL.config).to receive(:nullable_root_collections) { true }
      ::HQ::GraphQL.reset!
      build_resource!
    end

    it "emits a root collection as nullable" do
      expect(root_field_type("advisors")).to eq("AdvisorConnection")
    end

    it "leaves the singular root query alone" do
      # A single record was always nullable; nothing to relax, and nothing that
      # would change meaning if it were touched.
      expect(root_field_type("advisor")).to eq("Advisor")
    end
  end
end
