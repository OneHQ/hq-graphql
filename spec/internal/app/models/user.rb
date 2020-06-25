class User < ::ActiveRecord::Base
  belongs_to :advisor, optional: true
  belongs_to :manager, optional: true
  belongs_to :organization
end
