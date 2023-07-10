class Advisor < ActiveRecord::Base
  belongs_to :organization

  def hydrate
    self.name ||= "test name"
    self.organization_id ||= Organization.first.id
  end
end
