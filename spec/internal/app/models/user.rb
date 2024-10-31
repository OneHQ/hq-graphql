class User < ::ActiveRecord::Base
  belongs_to :advisor, optional: true
  belongs_to :manager, optional: true
  has_many :user_organizations, dependent: :destroy, class_name: "::HasHelpers::UserOrganization"
  has_many :organizations, class_name: "::HasHelpers::Organization", through: :user_organizations

  def hydrate
  end
end
