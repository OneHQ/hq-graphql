class Role < ::ActiveRecord::Base
  belongs_to :organization

  has_many :restrictions
end
