class EventParticipant < ApplicationRecord
  belongs_to :user
  belongs_to :event

  enum role: { attendee: 0, vendor: 1, organizer: 2 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }

  validates :user_id, uniqueness: { scope: :event_id }
  
  scope :vendors, -> { where(role: :vendor) }
  scope :attendees, -> { where(role: :attendee) }
  scope :organizers, -> { where(role: :organizer) }
  scope :confirmed, -> { where(rsvp_status: :yes) }

  def respond_to_rsvp!(status)
    update!(rsvp_status: status, responded_at: Time.current)
  end
end
