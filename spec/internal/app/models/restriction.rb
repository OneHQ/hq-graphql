class Restriction < ::ActiveRecord::Base
  belongs_to :organization
  belongs_to :resource
  belongs_to :role
end
