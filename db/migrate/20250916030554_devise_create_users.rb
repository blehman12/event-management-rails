class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:users)
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :first_name,         null: false
      t.string :last_name,          null: false
      t.string :phone
      t.string :company
      t.boolean :text_capable,      default: false
      t.integer :role,              default: 0
      t.integer :rsvp_status,       default: 0
      t.datetime :invited_at
      t.datetime :registered_at
      t.boolean :calendar_exported, default: false
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end
    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end
end
