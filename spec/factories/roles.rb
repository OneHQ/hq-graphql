FactoryBot.define do
  factory :role do
    name                   { Faker::Commerce.product_name }
    organization           { FactoryBot.create(:organization) }
  end
end
