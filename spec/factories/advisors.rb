FactoryBot.define do
  factory :advisor do
    name                    { Faker::Name.name }
    organization            { FactoryBot.build(:organization) }
  end
end
