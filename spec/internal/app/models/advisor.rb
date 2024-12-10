class Advisor < ActiveRecord::Base
  belongs_to :organization, class_name: "::HasHelpers::Organization"

  def hydrate
  end
end
