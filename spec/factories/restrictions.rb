FactoryBot.define do
  factory :restriction do
    resource                  { FactoryBot.create(:resource) }
    role                      { FactoryBot.create(:role) }
    restriction_operation_id  { "::HasHelpers::RestrictionOperation::#{["Create","Update", "Destroy", "Copy"].sample}" }
    organization              { FactoryBot.create(:organization) }
  end
end
