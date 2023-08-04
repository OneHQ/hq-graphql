FactoryBot.define do
  factory :resource do
    name                   { Faker::Commerce.product_name }
    resource_type_id       { "::HasHelpers::ResourceType::#{["BaseResource", "Field"].sample}" }
    parent                 { FactoryBot.create(:resource, resource_type_id: "::HasHelpers::ResourceType::::BaseResource") }
    field_resource         { [FactoryBot.create(:resource, resource_type_id: "::HasHelpers::ResourceType::::BaseResource"), nil].sample }
    field_class_name       { @field_resource.nil? ? nil : @field_resource&.name }
  end
end
