class Manager < ::ActiveRecord::Base
  belongs_to :organization, class_name: "::HasHelpers::Organization"

  has_many :active_users, -> { where(inactive: [nil, false]) }, class_name: "::HasHelpers::User"
  # has_many :users, inverse_of: :organization
  has_many :users, class_name: "::HasHelpers::User"
  has_many :advisors, through: :users
  has_many :not_joe, -> { where.not(name: "Joe" ) }, through: :users, source: :advisor
end
