require "rails_helper"

describe ::HQ::GraphQL::PaginatedAssociationLoader do
  let(:now) { Time.zone.now }

  let(:organization) { ::FactoryBot.create(:organization) }

  let(:manager1) { ::FactoryBot.create(:manager, organization: organization) }
  let(:manager2) { ::FactoryBot.create(:manager, organization: organization) }

  let!(:user1) { ::FactoryBot.create(:user, organization: organization, manager: manager1, created_at: now, updated_at: now + 1.minutes) }
  let!(:user2) { ::FactoryBot.create(:user, organization: organization, manager: manager1, created_at: now + 1.minutes, updated_at: now + 2.minutes, inactive: true) }
  let!(:user3) { ::FactoryBot.create(:user, organization: organization, manager: manager1, created_at: now + 2.minutes, updated_at: now) }

  before(:each) do
    # Create dummy data to verify data is properly filtered
    2.times { ::FactoryBot.create(:user, organization: organization, manager: manager2) }
  end

  def load(association, **options)
    results, _ = ::GraphQL::Batch.batch do
      loader = described_class.for(Manager, association, **options)
      # Load two associations to test that grouped limits + offsets work
      Promise.all([
                    loader.load(manager1),
                    loader.load(manager2)
                  ])
    end

    results
  end

  context "sort_by + sort_order" do
    it "sorts created_at in descending order by default" do
      users = load(:users)
      expect(users).to eq [user3, user2, user1]
    end

    it "sorts created_at in ascending order" do
      users = load(:users, sort_order: :asc)
      expect(users).to eq [user1, user2, user3]
    end

    it "sorts a column in descending order" do
      users = load(:users, sort_by: :updated_at, sort_order: :desc)
      expect(users).to eq [user2, user1, user3]
    end

    it "sorts a column in ascending order" do
      users = load(:users, sort_by: :updated_at, sort_order: :asc)
      expect(users).to eq [user3, user1, user2]
    end

    it "sorts with a scope" do
      users = load(:active_users)
      expect(users).to eq [user3, user1]
    end
  end

  context "limit + offset" do
    it "offsets by 1" do
      users = load(:users, offset: 1)
      expect(users).to eq [user2, user1]
    end

    it "limits by 2" do
      users = load(:users, limit: 2, sort_order: :asc)
      expect(users).to eq [user1, user2]
    end

    it "returns active users" do
      users = load(:active_users, sort_by: :updated_at, limit: 3, offset: 0, sort_order: :asc)
      expect(users).to eq [user3, user1]
    end

    it "returns the second active user" do
      users = load(:active_users, sort_by: :updated_at, offset: 1, limit: 1, sort_order: :asc)
      expect(users).to eq [user1]
    end
  end

  context "has many through" do
    let(:advisor1) { ::FactoryBot.create(:advisor, organization: organization, created_at: now) }
    let(:advisor2) { ::FactoryBot.create(:advisor, organization: organization, created_at: now - 1.minutes, name: "Joe") }
    let(:advisor3) { ::FactoryBot.create(:advisor, organization: organization, created_at: now - 2.minutes) }

    before(:each) do
      user1.update(advisor: advisor1)
      user2.update(advisor: advisor2)
      user3.update(advisor: advisor3)

      # Create dummy data to verify data is properly filtered
      other_user = ::User.find_by(manager: manager2)
      2.times do
        advisor = ::FactoryBot.create(:advisor, organization: organization)
        other_user.update(advisor: advisor)
      end
    end

    context "sort_by + sort_order" do
      it "sorts created_at in descending order by default" do
        advisors = load(:advisors)
        expect(advisors).to eq [advisor1, advisor2, advisor3]
      end

      it "sorts created_at in ascending order" do
        advisors = load(:advisors, sort_order: :asc)
        expect(advisors).to eq [advisor3, advisor2, advisor1]
      end

      it "sorts a column in descending order" do
        advisors = load(:advisors, sort_by: :updated_at, sort_order: :desc)
        expect(advisors).to eq [advisor3, advisor2, advisor1]
      end

      it "sorts a column in ascending order" do
        advisors = load(:advisors, sort_by: :updated_at, sort_order: :asc)
        expect(advisors).to eq [advisor1, advisor2, advisor3]
      end

      it "sorts with a scope" do
        advisors = load(:not_joe)
        expect(advisors).to eq [advisor1, advisor3]
      end
    end

    context "limit + offset" do
      it "offsets by 1" do
        advisors = load(:advisors, offset: 1)
        expect(advisors).to eq [advisor2, advisor3]
      end

      it "limits by 2" do
        advisors = load(:advisors, limit: 2, sort_order: :asc)
        expect(advisors).to eq [advisor3, advisor2]
      end

      it "returns active advisors" do
        advisors = load(:not_joe, sort_by: :updated_at, limit: 3, offset: 0, sort_order: :desc)
        expect(advisors).to eq [advisor3, advisor1]
      end

      it "returns the second active user" do
        advisors = load(:not_joe, sort_by: :updated_at, offset: 1, limit: 1, sort_order: :desc)
        expect(advisors).to eq [advisor1]
      end
    end
  end
end
