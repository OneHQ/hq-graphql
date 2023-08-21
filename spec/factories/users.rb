FactoryBot.define do
  factory :user do
    name                { Faker::Name.name }
    organization        { FactoryBot.build(:organization) }
    role                { FactoryBot.build(:role) }
  end
end
