FactoryBot.define do
  factory :resource do
    name                   { Faker::Commerce.product_name }
    add_attribute(:alias)  { @alias ? @alias : @name }
    resource_type_id       { "::HasHelpers::ResourceType::#{["Base", "Field"].sample}" }
    parent                 { FactoryBot.create(:resource, resource_type_id: "::HasHelpers::ResourceType::::Base") }
    field_resource         { [FactoryBot.create(:resource, resource_type_id: "::HasHelpers::ResourceType::::Base"), nil].sample }
    field_class_name       { @field_resource.nil? ? nil : @field_resource&.name }
  end
end
