require "rails_helper"

# `nullable_associations` relaxes the OUTER wrapper of association fields on
# output types, so a host app whose authorization returns nil for a denied
# record does not lose the whole payload to non-null propagation.
describe "HQ::GraphQL.nullable_associations?" do
  def build_resources!
    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "Manager"
      query
    end

    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "User"
      query
    end

    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "Organization"
      query
    end

    Class.new do
      include ::HQ::GraphQL::Resource
      self.model_name = "TestType"
      query
    end
  end

  def type_of(model_name, field_name)
    query_object = ::HQ::GraphQL::Types[model_name.constantize]
    query_object.lazy_load!
    query_object.fields[field_name].type.to_type_signature
  end

  before(:each) do
    ::HQ::GraphQL.reset!
    build_resources!
    ::HQ::GraphQL.load_types!
  end

  after(:each) { ::HQ::GraphQL.reset! }

  context "off (the default)" do
    it "is disabled unless the host opts in" do
      expect(::HQ::GraphQL.nullable_associations?).to be false
    end

    it "emits has_many as a non-null list" do
      expect(type_of("Manager", "users")).to eq("[User!]!")
    end

    it "emits a required belongs_to as non-null" do
      expect(type_of("Manager", "organization")).to eq("Organization!")
    end
  end

  context "on" do
    before(:each) do
      allow(::HQ::GraphQL.config).to receive(:nullable_associations) { true }
      ::HQ::GraphQL.reset!
      build_resources!
      ::HQ::GraphQL.load_types!
    end

    it "relaxes only the outer wrapper of a has_many" do
      # [T!]! -> [T!]. Elements stay non-null: a per-record denial must shorten
      # the list, never leave a hole in it.
      expect(type_of("Manager", "users")).to eq("[User!]")
    end

    it "relaxes a required belongs_to" do
      expect(type_of("Manager", "organization")).to eq("Organization")
    end

    it "relaxes a has_one" do
      expect(type_of("TestType", "selfReference")).to eq("TestType")
    end

    it "leaves non-null scalar columns untouched" do
      expect(type_of("Manager", "id")).to eq("UUID!")
    end
  end
end
