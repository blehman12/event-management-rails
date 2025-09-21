class Event < ApplicationRecord
  # Associations
  belongs_to :venue
  belongs_to :creator, class_name: 'User'
  has_many :event_participants, dependent: :destroy
  has_many :users, through: :event_participants
  has_many :vendors, -> { where(event_participants: { role: :vendor }) },
           through: :event_participants, source: :user
  has_many :organizers, -> { where(event_participants: { role: :organizer }) },
           through: :event_participants, source: :user

  # Validations
  validates :name, :event_date, :rsvp_deadline, presence: true
  validates :max_attendees, presence: true, numericality: { greater_than: 0 }
  validate :rsvp_deadline_before_event_date

  # Scopes
  scope :upcoming, -> { where('event_date > ?', Time.current) }
  scope :past, -> { where('event_date < ?', Time.current) }

  # Serialization for custom questions
  serialize :custom_questions, coder: JSON

  # Callbacks
  before_save :ensure_custom_questions_array

  # Public methods
  def attendees_count
    event_participants.where(rsvp_status: ['yes', '1']).count
  end

  def vendors_count
    event_participants.vendor.count
  end

  def rsvp_open?
    rsvp_deadline.present? && Time.current <= rsvp_deadline
  end


  def spots_remaining
    max_attendees - attendees_count
  end

  def days_until_deadline
    return 0 if rsvp_deadline.blank? || rsvp_deadline < Time.current
    ((rsvp_deadline - Time.current) / 1.day).ceil
  end

  def add_participant(user, role: :attendee)
    event_participants.find_or_create_by(user: user) do |participant|
      participant.role = role
      participant.invited_at = Time.current
    end
  end

  private

  def rsvp_deadline_before_event_date
    return unless rsvp_deadline && event_date
    
    if rsvp_deadline >= event_date
      errors.add(:rsvp_deadline, "must be before event date")
    end
  end

  def ensure_custom_questions_array
    self.custom_questions = [] if custom_questions.blank?
  end
end