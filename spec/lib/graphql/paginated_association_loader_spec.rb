require 'rails_helper'

describe ::HQ::GraphQL::PaginatedAssociationLoader do
  let(:organization1) { ::FactoryBot.create(:organization) }
  let(:organization2) { ::FactoryBot.create(:organization) }

  let(:now) { Time.zone.now }

  let!(:user1_1) { ::FactoryBot.create(:user, organization: organization1, created_at: now, updated_at: now + 1.minutes) }
  let!(:user1_2) { ::FactoryBot.create(:user, organization: organization1, created_at: now + 1.minutes, updated_at: now + 2.minutes, inactive: true) }
  let!(:user1_3) { ::FactoryBot.create(:user, organization: organization1, created_at: now + 2.minutes, updated_at: now) }
  let!(:user2_1) { ::FactoryBot.create(:user, organization: organization2, created_at: now, updated_at: now - 1.minutes) }
  let!(:user2_2) { ::FactoryBot.create(:user, organization: organization2, created_at: now + 1.minutes, updated_at: now) }

  def load(association, **options)
    users, _ = ::GraphQL::Batch.batch do
      loader = described_class.for(Organization, association, **options)
      # Load two associations to test that grouped limits + offsets work
      Promise.all([
        loader.load(organization1),
        loader.load(organization2)
      ])
    end

    users
  end

  context "sort_by + sort_order" do
    it "sorts updated_at in descending order by default" do
      users = load(:users)
      expect(users).to eq [user1_2, user1_1, user1_3]
    end

    it "sorts updated_at in ascending order" do
      users = load(:users, sort_order: :asc)
      expect(users).to eq [user1_3, user1_1, user1_2]
    end

    it "sorts a column in descending order" do
      users = load(:users, sort_by: :created_at, sort_order: :desc)
      expect(users).to eq [user1_3, user1_2, user1_1]
    end

    it "sorts a column in ascending order" do
      users = load(:users, sort_by: :created_at, sort_order: :asc)
      expect(users).to eq [user1_1, user1_2, user1_3]
    end
  end

  context "limit + offset" do
    it "offsets by 1" do
      users = load(:users, offset: 1)
      expect(users).to eq [user1_1, user1_3]
    end

    it "limits by 2" do
      users = load(:users, limit: 2, sort_order: :asc)
      expect(users).to eq [user1_3, user1_1]
    end

    it "returns active users" do
      users = load(:active_users, sort_by: :created_at, limit: 3, offset: 0, sort_order: :asc)
      expect(users).to eq [user1_1, user1_3]
    end

    it "returns the second active user" do
      users = load(:active_users, sort_by: :created_at, offset: 1, limit: 1, sort_order: :asc)
      expect(users).to eq [user1_3]
    end
  end

  xcontext "has many through" do
    it do
      organizations = load(:user_organizations, limit: 1, offset: 1, sort_by: :updated_at)
      expect(organizations).to eq [organization1]
    end

    it do
      organizations = load(:user_organizations, sort_by: :updated_at)
      expect(organizations).to eq [organization1, organization1, organization1]
    end
  end
end
