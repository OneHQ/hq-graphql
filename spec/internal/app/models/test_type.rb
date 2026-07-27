class TestType < ::ActiveRecord::Base
  # self-referential association used only to exercise left_outer_joins in specs
  has_one :self_reference, class_name: "TestType", foreign_key: :id, inverse_of: false
end
