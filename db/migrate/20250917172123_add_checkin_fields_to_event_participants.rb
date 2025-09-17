class AddCheckinFieldsToEventParticipants < ActiveRecord::Migration[7.1]
  def change
    add_column :event_participants, :checked_in_at, :datetime
    add_column :event_participants, :check_in_method, :string
    add_column :event_participants, :qr_code_token, :string
    
    # Change this line to allow null: true
    add_reference :event_participants, :checked_in_by, null: true, foreign_key: { to_table: :users }
    
    # Add indexes for performance
    add_index :event_participants, :qr_code_token, unique: true
    add_index :event_participants, :checked_in_at
  end
end