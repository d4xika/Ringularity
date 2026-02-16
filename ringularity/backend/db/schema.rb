# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_16_121754) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "heart_rate_logs", force: :cascade do |t|
    t.integer "bpm"
    t.datetime "created_at", null: false
    t.string "device_id"
    t.datetime "recorded_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["device_id", "recorded_at", "user_id"], name: "unique_heart_rate_logs", unique: true
    t.index ["user_id"], name: "index_heart_rate_logs_on_user_id"
  end

  create_table "hrv_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id"
    t.integer "hrv_val"
    t.datetime "recorded_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["device_id", "recorded_at", "user_id"], name: "unique_hrv_logs", unique: true
    t.index ["user_id"], name: "index_hrv_logs_on_user_id"
  end

  create_table "sleep_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id"
    t.integer "duration_minutes"
    t.datetime "recorded_at"
    t.integer "sleep_stage"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["device_id", "recorded_at", "user_id"], name: "unique_sleep_logs", unique: true
    t.index ["user_id"], name: "index_sleep_logs_on_user_id"
  end

  create_table "steps_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id"
    t.datetime "recorded_at"
    t.integer "steps"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["device_id", "recorded_at", "user_id"], name: "unique_steps_logs", unique: true
    t.index ["user_id"], name: "index_steps_logs_on_user_id"
  end

  create_table "stress_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_id"
    t.datetime "recorded_at"
    t.integer "stress_level"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["device_id", "recorded_at", "user_id"], name: "unique_stress_logs", unique: true
    t.index ["user_id"], name: "index_stress_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "auth_key"
    t.date "birthday"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "heart_rate_logs", "users"
  add_foreign_key "hrv_logs", "users"
  add_foreign_key "sleep_logs", "users"
  add_foreign_key "steps_logs", "users"
  add_foreign_key "stress_logs", "users"
end
