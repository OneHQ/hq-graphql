class Role < ::ActiveRecord::Base
  belongs_to :organization

  has_many :restrictions
  has_many :users
end
