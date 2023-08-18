class Advisor < ActiveRecord::Base
  belongs_to :organization
  belongs_to :optional_org, class_name: "::Organization", optional: true

  def hydrate
  end
end
