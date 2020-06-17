class Organization < ::ActiveRecord::Base
  has_many :active_users, -> { where(inactive: [nil, false]) }, class_name: "User"
  has_many :users, inverse_of: :organization
  has_many :user_organizations, through: :users, class_name: "Organization", source: :organization
end
