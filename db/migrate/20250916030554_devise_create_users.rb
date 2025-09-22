class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:users)
    
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :company
      t.string :role, default: 'attendee'
      t.boolean :text_capable, default: true
      t.datetime :invited_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end
end
