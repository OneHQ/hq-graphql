class Advisor < ActiveRecord::Base
  belongs_to :organization

  def hydrate
  end
end
