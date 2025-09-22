class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:events)
    create_table :events do |t|
      t.string :name
      t.text :description
      t.datetime :event_date
      t.time :start_time
      t.time :end_time
      t.integer :max_attendees
      t.datetime :rsvp_deadline
      t.integer :venue_id
      t.integer :creator_id

      t.timestamps
    end
  end
end
