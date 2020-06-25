FactoryBot.define do
  factory :manager do
    organization            { FactoryBot.build(:organization) }
  end
end
