class Resource < ::ActiveRecord::Base
  belongs_to :parent, class_name: "::Resource", optional: true
  belongs_to :field_resource, class_name: "::Resource", optional: true

  has_many :resources, foreign_key: "parent_id", dependent: :destroy, inverse_of: :parent
  has_many :resources, foreign_key: "field_resource_id", dependent: :destroy, inverse_of: :field_resource
  has_many :restrictions
end
