require "rails_helper"

# A generated mutation used to authorize only its OWN model and action, so any
# association writable through nested attributes bypassed its own resource
# authorization: forbidden to create a User, you could still create one by
# sending it inside a Manager update. `config.authorize_nested_attributes`
# closes that.
#
# These specs cover the walk itself -- which class is asked about, which action
# is inferred, and how far it recurses. The end-to-end mutation behaviour (that
# a violation rejects the mutation and writes nothing) is covered by the host
# app, which has a schema and real nested-attribute models to execute against.
describe ::HQ::GraphQL::NestedAuthorization do
  # Records every question asked. The ACTION matters as much as the class: it
  # is inferred from the row, and inferring it wrong would authorize something
  # other than what is about to happen while still looking like it works.
  let(:asked) { [] }

  def authorize!(denied: [])
    allow(::HQ::GraphQL.config).to receive(:authorize_nested_attributes) do
      ->(action, klass, parent_klass, _context) do
        asked << [action, klass.name, parent_klass.name]
        !denied.include?([action, klass.name])
      end
    end
  end

  def errors_for(attributes)
    described_class.errors(Manager, attributes, {})
  end

  describe "opting in" do
    it "is inert until the host sets the hook" do
      expect(::HQ::GraphQL.authorize_nested_attributes(:create, User, Manager, {})).to be true
    end

    it "asks nothing when there are no nested attributes" do
      authorize!

      expect(errors_for(name: "Ada")).to be_empty
      expect(asked).to be_empty
    end
  end

  describe "the question asked" do
    before(:each) { authorize! }

    it "names the association's class, with the owner as the parent" do
      errors_for(users_attributes: [{ name: "Ada" }])

      expect(asked).to eq([[:create, "User", "Manager"]])
    end

    it "infers update from a primary key" do
      errors_for(users_attributes: [{ id: SecureRandom.uuid, name: "Ada" }])

      expect(asked).to eq([[:update, "User", "Manager"]])
    end

    it "infers destroy from _destroy" do
      errors_for(users_attributes: [{ id: SecureRandom.uuid, _destroy: true }])

      expect(asked).to eq([[:destroy, "User", "Manager"]])
    end

    it "infers destroy from the X marker, even though the row carries an id" do
      # The host's `X=` writer calls mark_for_destruction. A row removed this
      # way still has its id, so reading the id first would call it an update
      # and let a delete restriction through.
      errors_for(users_attributes: [{ id: SecureRandom.uuid, X: "X" }])

      expect(asked).to eq([[:destroy, "User", "Manager"]])
    end

    it "ignores an X that is not the marker" do
      errors_for(users_attributes: [{ id: SecureRandom.uuid, X: nil }])

      expect(asked).to eq([[:update, "User", "Manager"]])
    end

    it "ignores a falsey _destroy" do
      errors_for(users_attributes: [{ id: SecureRandom.uuid, _destroy: false }])

      expect(asked).to eq([[:update, "User", "Manager"]])
    end

    it "asks once per row" do
      errors_for(users_attributes: [{ name: "Ada" }, { id: SecureRandom.uuid, name: "Grace" }])

      expect(asked).to eq([[:create, "User", "Manager"], [:update, "User", "Manager"]])
    end

    it "recurses, asking about each level against its own owner" do
      errors_for(users_attributes: [{ name: "Ada", advisor_attributes: { name: "Joe" } }])

      expect(asked).to eq([[:create, "User", "Manager"], [:create, "Advisor", "User"]])
    end

    it "skips keys that are not nested attributes" do
      errors_for(name: "Ada", organization_id: 1)

      expect(asked).to be_empty
    end
  end

  describe "the result" do
    it "is empty when every association is permitted" do
      authorize!

      expect(errors_for(users_attributes: [{ name: "Ada" }])).to be_empty
    end

    it "names the association and the refused action" do
      authorize!(denied: [[:create, "User"]])

      expect(errors_for(users_attributes: [{ name: "Ada" }]))
        .to eq({ "users" => ["You are not allowed to create users"] })
    end

    it "reports an association once however many rows were refused" do
      authorize!(denied: [[:create, "User"]])

      errors = errors_for(users_attributes: [{ name: "Ada" }, { name: "Grace" }])

      expect(errors["users"].length).to eq(1)
    end

    it "distinguishes actions on the same association" do
      authorize!(denied: [[:create, "User"], [:update, "User"]])

      errors = errors_for(users_attributes: [{ name: "Ada" }, { id: SecureRandom.uuid, name: "Grace" }])

      expect(errors["users"]).to contain_exactly(
        "You are not allowed to create users",
        "You are not allowed to update users"
      )
    end

    it "keys the refusal by the input field the client sent" do
      authorize!(denied: [[:create, "User"]])

      expect(errors_for(active_users_attributes: [{ name: "Ada" }]).keys).to eq(["activeUsers"])
    end

    it "reports a denial found further down the tree" do
      authorize!(denied: [[:create, "Advisor"]])

      expect(errors_for(users_attributes: [{ name: "Ada", advisor_attributes: { name: "Joe" } }]))
        .to eq({ "advisor" => ["You are not allowed to create advisors"] })
    end
  end
end
