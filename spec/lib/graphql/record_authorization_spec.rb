require "rails_helper"

# A generated mutation authorized only its own model, so a restriction authored under the
# record's owner (`Manager -> User`) was never found: a role forbidden to update a manager's
# users could still update one through `updateUser`. `config.record_parents` lets the host
# say whose a record is, and the mutation then asks about the record AS A CHILD of each
# parent through `config.authorize_nested_attributes`.
describe ::HQ::GraphQL::RecordAuthorization do
  let(:asked) { [] }
  let(:denied) { [] }

  # Who a user belongs to: its manager, when it has one.
  let(:record_parents) { ->(record, _context) { record.manager_id ? [Manager] : [] } }

  def opt_in!
    allow(::HQ::GraphQL.config).to receive(:record_parents) { record_parents }
    allow(::HQ::GraphQL.config).to receive(:authorize_nested_attributes) do
      ->(action, klass, parent_klass, _context) do
        asked << [action, klass.name, parent_klass.name]
        !denied.include?([action, parent_klass.name])
      end
    end
  end

  describe "opting in" do
    it "is inert until the host sets the hooks" do
      expect(described_class.parents(User.new(manager_id: SecureRandom.uuid), {})).to eq([])
      expect(described_class.refusal(:update, User.new(manager_id: SecureRandom.uuid), {})).to be_nil
    end

    it "asks nothing of a record that belongs to nobody" do
      opt_in!

      expect(described_class.refusal(:update, User.new, {})).to be_nil
      expect(asked).to be_empty
    end
  end

  describe ".refusal" do
    before(:each) { opt_in! }

    let(:user) { User.new(manager_id: SecureRandom.uuid) }

    it "asks about the record's class as a child of each parent" do
      described_class.refusal(:update, user, {})

      expect(asked).to eq([[:update, "User", "Manager"]])
    end

    it "is nil when every parent allows it" do
      expect(described_class.refusal(:update, user, {})).to be_nil
    end

    it "words a refusal like the mutation's own" do
      denied << [:update, "Manager"]

      expect(described_class.refusal(:update, user, {})).to eq("You are not allowed to update users")
    end

    it "asks about the parents it is given instead of the record's own" do
      described_class.refusal(:update, user, {}, parents: [Advisor])

      expect(asked).to eq([[:update, "User", "Advisor"]])
    end

    it "ignores empty and repeated parents the host returns" do
      allow(::HQ::GraphQL.config).to receive(:record_parents) { ->(_r, _c) { [Manager, nil, Manager] } }

      described_class.refusal(:update, user, {})

      expect(asked).to eq([[:update, "User", "Manager"]])
    end
  end

  describe "in the generated mutations" do
    let(:user_resource) do
      Class.new do
        include ::HQ::GraphQL::Resource
        self.model_name = "User"

        root_query
      end
    end

    let(:root_query) { Class.new(::HQ::GraphQL::RootQuery) }

    # The types a user's associations point at.
    let(:related_resources) do
      %w[Organization Advisor Manager].map do |name|
        Class.new do
          include ::HQ::GraphQL::Resource
          self.model_name = name
        end
      end
    end

    let(:root_mutation) do
      Class.new(::HQ::GraphQL::RootMutation) do
        # RootMutation is invalid with no fields.
        field :do_nothing, String, null: true
      end
    end

    let(:schema) do
      Class.new(::GraphQL::Schema) do
        query(::RootQuery)
        mutation(::RootMutation)
        use(::GraphQL::Batch)
      end
    end

    let(:organization) { FactoryBot.create(:organization) }
    let(:manager) { FactoryBot.create(:manager, organization: organization) }
    let(:other_manager) { FactoryBot.create(:manager, organization: organization) }
    let!(:user) { FactoryBot.create(:user, organization: organization, manager: manager) }

    before(:each) do
      allow(::HQ::GraphQL.config).to receive(:use_experimental_associations) { true }
      related_resources
      user_resource
      stub_const("RootQuery", root_query)
      stub_const("RootMutation", root_mutation)
      # After the root mutation exists: the types load last in, first out, and the
      # mutations' arguments have to be there before the root mutation copies them.
      user_resource.class_eval { mutations }
      opt_in!
    end

    def run(query, variables)
      schema.execute(query, variables: variables)["data"]
    end

    let(:update) do
      <<-GRAPHQL
        mutation updateUser($id: ID!, $attributes: UserInput!) {
          updateUser(id: $id, attributes: $attributes) { errors resource { id } }
        }
      GRAPHQL
    end

    let(:create) do
      <<-GRAPHQL
        mutation createUser($attributes: UserInput!) {
          createUser(attributes: $attributes) { errors resource { id } }
        }
      GRAPHQL
    end

    let(:destroy) do
      <<-GRAPHQL
        mutation destroyUser($id: ID!) {
          destroyUser(id: $id) { errors resource { id } }
        }
      GRAPHQL
    end

    let(:copy) do
      <<-GRAPHQL
        mutation copyUser($id: ID!) {
          copyUser(id: $id) { errors resource { id } }
        }
      GRAPHQL
    end

    let(:refused) { { "base" => ["You are not allowed to update users"] } }

    it "refuses an update the role may not make under the record's owner, and writes nothing" do
      denied << [:update, "Manager"]

      data = run(update, id: user.id, attributes: { name: "Renamed" })

      expect(data["updateUser"]).to eq("errors" => refused, "resource" => nil)
      expect(user.reload.name).not_to eq("Renamed")
    end

    it "lets an update through when the owner allows it" do
      data = run(update, id: user.id, attributes: { name: "Renamed" })

      expect(data["updateUser"]["errors"]).to eq({})
      expect(user.reload.name).to eq("Renamed")
    end

    it "asks about an owner the update would hand the record to as a create, and refuses it" do
      allow(::HQ::GraphQL.config).to receive(:record_parents) do
        ->(record, _context) { record.manager_id == other_manager.id ? [Advisor] : [Manager] }
      end
      denied << [:create, "Advisor"]

      data = run(update, id: user.id, attributes: { managerId: other_manager.id })

      # Worded for what it is: adding the record under the new owner.
      expect(data["updateUser"]["errors"]).to eq("base" => ["You are not allowed to create users"])
      expect(user.reload.manager_id).to eq(manager.id)
    end

    it "does not ask again about owners the record keeps" do
      run(update, id: user.id, attributes: { name: "Renamed" })

      expect(asked).to eq([[:update, "User", "Manager"]])
    end

    it "asks about the owner it is left with as a create, and about the one it had as an update" do
      allow(::HQ::GraphQL.config).to receive(:record_parents) do
        ->(record, _context) { record.manager_id == other_manager.id ? [Advisor] : [Manager] }
      end

      run(update, id: user.id, attributes: { managerId: other_manager.id })

      expect(asked).to eq([[:update, "User", "Manager"], [:create, "User", "Advisor"]])
    end

    it "refuses a create under an owner the role may not create under" do
      denied << [:create, "Manager"]

      data = run(create, attributes: { name: "New", organizationId: organization.id, managerId: manager.id })

      expect(data["createUser"]["errors"]).to eq("base" => ["You are not allowed to create users"])
      expect(User.where(name: "New")).to be_empty
    end

    it "refuses a destroy the role may not make under the record's owner" do
      denied << [:destroy, "Manager"]

      data = run(destroy, id: user.id)

      expect(data["destroyUser"]["errors"]).to eq("base" => ["You are not allowed to delete users"])
      expect(User.exists?(user.id)).to be true
    end

    # The copy is a record of its own under the same owner, so it is asked as a copy.
    describe "copying" do
      before(:each) do
        User.send(:define_method, :copy) do
          User.new(name: "#{name} copy", organization_id: organization_id, manager_id: manager_id)
        end
      end

      after(:each) { User.send(:remove_method, :copy) }

      it "refuses a copy the role may not make under the record's owner, and writes nothing" do
        denied << [:copy, "Manager"]

        data = run(copy, id: user.id)

        expect(data["copyUser"]).to eq("errors" => { "base" => ["You are not allowed to copy users"] }, "resource" => nil)
        expect(User.where(name: "#{user.name} copy")).to be_empty
        expect(asked).to eq([[:copy, "User", "Manager"]])
      end

      it "copies when the owner allows it" do
        data = run(copy, id: user.id)

        expect(data["copyUser"]["errors"]).to eq({})
        expect(User.where(name: "#{user.name} copy").count).to eq(1)
      end
    end

    it "changes nothing for a host that has not opted in" do
      allow(::HQ::GraphQL.config).to receive(:record_parents).and_return(nil)
      denied << [:update, "Manager"]

      data = run(update, id: user.id, attributes: { name: "Renamed" })

      expect(data["updateUser"]["errors"]).to eq({})
    end
  end
end
