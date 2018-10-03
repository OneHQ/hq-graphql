ActiveRecord::Schema.define do
  enable_extension "uuid-ossp"

  create_table "organizations", force: true, id: :uuid do |t|
    t.string   :name,                  limit: 63, null: false
    t.timestamps                       null: false
  end

  create_table "users", force: true, id: :uuid do |t|
    t.belongs_to  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.string      :name,               null: false
    t.timestamps                       null: false
  end

  create_table "advisors", force: true, id: :uuid do |t|
    t.references  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.string      :name,               null: false
    t.timestamps                       null: false
  end

end
