require "rails_helper"

# `authorize_association_target` decides WHICH class an association field hands
# to `config.authorize_field`.
#
# Historically every association field was built with `klass: model_name` -- the
# OWNER of the association. A host asking "may this user see this field?" was
# therefore always asked about the owner (`Advisor` for `advisor.salesManagers`),
# which it had already answered to reach the field at all. The question could
# never be "may this user see SalesManager?", so a resource-level denial had no
# way to fire at the field, and fell through to the per-record object hook --
# which can only null individual list ELEMENTS, violating the non-null element
# type and producing an error instead of a clean null field.
describe "HQ::GraphQL.authorize_association_target?" do
  def build_resources!
    %w[Manager User Organization TestType].each do |model|
      Class.new do
        include ::HQ::GraphQL::Resource
        self.model_name = model
        query
      end
    end
  end

  def klass_of(model_name, field_name)
    query_object = ::HQ::GraphQL::Types[model_name.constantize]
    query_object.lazy_load!
    query_object.fields[field_name].klass
  end

  before(:each) do
    ::HQ::GraphQL.reset!
    build_resources!
    ::HQ::GraphQL.load_types!
  end

  after(:each) { ::HQ::GraphQL.reset! }

  context "off (the default)" do
    it "is disabled unless the host opts in" do
      expect(::HQ::GraphQL.authorize_association_target?).to be false
    end

    it "hands the owner to authorize_field for a has_many" do
      expect(klass_of("Manager", "users")).to eq(Manager)
    end

    it "hands the owner to authorize_field for a belongs_to" do
      expect(klass_of("Manager", "organization")).to eq(Manager)
    end
  end

  context "on" do
    before(:each) do
      allow(::HQ::GraphQL.config).to receive(:authorize_association_target) { true }
      ::HQ::GraphQL.reset!
      build_resources!
      ::HQ::GraphQL.load_types!
    end

    it "hands the association's target class for a has_many" do
      expect(klass_of("Manager", "users")).to eq(User)
    end

    it "hands the association's target class for a belongs_to" do
      expect(klass_of("Manager", "organization")).to eq(Organization)
    end

    it "hands the association's target class for a has_one" do
      expect(klass_of("TestType", "selfReference")).to eq(TestType)
    end

    it "leaves plain column fields without a klass" do
      expect(klass_of("Manager", "id")).to be_nil
    end
  end
end
