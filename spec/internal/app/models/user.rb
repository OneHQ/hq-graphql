class User < ::ActiveRecord::Base
  belongs_to :organization, inverse_of: :users
end
