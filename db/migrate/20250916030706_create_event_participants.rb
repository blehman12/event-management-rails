class CreateEventParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :event_participants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.integer :role, default: 0  # attendee: 0, vendor: 1, organizer: 2
      t.integer :rsvp_status, default: 0  # pending: 0, yes: 1, no: 2, maybe: 3
      t.text :notes
      t.datetime :invited_at
      t.datetime :responded_at
      t.timestamps
    end

    add_index :event_participants, [:user_id, :event_id], unique: true
    add_index :event_participants, :role
    add_index :event_participants, :rsvp_status
  end
end
