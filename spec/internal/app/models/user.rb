class User < ::ActiveRecord::Base
  belongs_to :advisor, optional: true
  belongs_to :manager, optional: true
  belongs_to :organization
  belongs_to :role

  has_many :restrictions, through: :role

  def hydrate
  end
end
