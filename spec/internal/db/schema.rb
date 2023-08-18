# frozen_string_literal: true

ActiveRecord::Schema.define do
  enable_extension "uuid-ossp"
  enable_extension "pgcrypto"

  create_table "organizations", force: true, id: :uuid do |t|
    t.string   :name,                  limit: 63, null: false
    t.timestamps                       null: false
  end

  create_table "advisors", force: true, id: :uuid do |t|
    t.references  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.uuid        :optional_org_id
    t.string      :name,               null: false
    t.string      :nickname
    t.timestamps                       null: false
  end
  add_foreign_key :advisors, :organizations, column: :optional_org_id

  create_table "managers", force: true, id: :uuid do |t|
    t.references  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.timestamps                       null: false
  end

  create_table "roles", force: true, id: :uuid do |t|
    t.references  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.string      :name,               null: false
  end

  create_table "resources", force: true, id: :uuid do |t|
    t.string      :name,               null: false
    t.string      :alias,              null: false
    t.string      :resource_type_id,   null: false
    t.uuid        :parent_id
    t.uuid        :field_resource_id
    t.string      :field_class_name
  end
  add_foreign_key :resources, :resources, column: :parent_id
  add_foreign_key :resources, :resources, column: :field_resource_id

  create_table "restrictions", force: true, id: :uuid do |t|
    t.references  :organization,              null: false, index: true, foreign_key: true, type: :uuid
    t.references  :role,                      null: false, index: true, foreign_key: true, type: :uuid
    t.references  :resource,                  null: false, index: true, foreign_key: true, type: :uuid
    t.string      :restriction_operation_id,  null: false
  end

  create_table "users", force: true, id: :uuid do |t|
    t.belongs_to  :organization,       null: false, index: true, foreign_key: true, type: :uuid
    t.belongs_to  :advisor,            null: true, index: true, foreign_key: true, type: :uuid
    t.belongs_to  :manager,            null: true, index: true, foreign_key: true, type: :uuid
    t.boolean     :inactive
    t.string      :name,               null: false
    t.timestamps                       null: false
  end

  create_table "test_types", force: true, id: :uuid do |t|
    t.jsonb       :data_jsonb
    t.json        :data_json
    t.integer     :count
    t.decimal     :amount
    t.boolean     :is_bool
    t.string      :name
    t.date        :created_date
    t.timestamps
  end
end
