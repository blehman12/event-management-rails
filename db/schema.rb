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

ActiveRecord::Schema[7.1].define(version: 2025_09_21_215209) do
  create_table "event_participants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "event_id", null: false
    t.integer "role", default: 0
    t.integer "rsvp_status", default: 0
    t.text "notes"
    t.datetime "invited_at"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "rsvp_answers"
    t.datetime "checked_in_at"
    t.string "check_in_method"
    t.string "qr_code_token"
    t.integer "checked_in_by_id"
    t.index ["checked_in_at"], name: "index_event_participants_on_checked_in_at"
    t.index ["checked_in_by_id"], name: "index_event_participants_on_checked_in_by_id"
    t.index ["event_id"], name: "index_event_participants_on_event_id"
    t.index ["qr_code_token"], name: "index_event_participants_on_qr_code_token", unique: true
    t.index ["role"], name: "index_event_participants_on_role"
    t.index ["rsvp_status"], name: "index_event_participants_on_rsvp_status"
    t.index ["user_id", "event_id"], name: "index_event_participants_on_user_id_and_event_id", unique: true
    t.index ["user_id"], name: "index_event_participants_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "event_date"
    t.time "start_time"
    t.time "end_time"
    t.integer "max_attendees"
    t.datetime "rsvp_deadline"
    t.integer "venue_id"
    t.integer "creator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "custom_questions"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.string "company"
    t.boolean "text_capable", default: false
    t.integer "role", default: 0
    t.integer "rsvp_status", default: 0
    t.datetime "invited_at"
    t.datetime "registered_at"
    t.boolean "calendar_exported", default: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.text "description"
    t.integer "capacity"
    t.text "contact_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "event_participants", "events"
  add_foreign_key "event_participants", "users"
  add_foreign_key "event_participants", "users", column: "checked_in_by_id"
end
