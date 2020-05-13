FactoryBot.define do
  factory :advisor do
    name                    { Faker::Name.name }
    nickname                { Faker::Name.first_name }
    organization            { FactoryBot.build(:organization) }

    # This is being used for the enum tests.
    # Enums only allow letters as their value.
    trait :simple_name do
      name                  { Faker::Name.name.delete(".,'") }
    end
  end
end
