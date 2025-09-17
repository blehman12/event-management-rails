class AddRsvpAnswersToEventParticipants < ActiveRecord::Migration[7.1]
  def change
    add_column :event_participants, :rsvp_answers, :text
  end
end
