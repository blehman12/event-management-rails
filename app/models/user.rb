class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { attendee: 0, admin: 1 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }

  has_many :event_participants, dependent: :destroy
  has_many :events, through: :event_participants
  has_many :created_events, class_name: 'Event', foreign_key: 'creator_id'
  has_many :vendor_events, -> { where(event_participants: { role: :vendor }) }, 
           through: :event_participants, source: :event

  validates :first_name, :last_name, :phone, :company, presence: true

  scope :invited, -> { where.not(invited_at: nil) }
  scope :registered, -> { where.not(registered_at: nil) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def role_for_event(event)
    event_participants.find_by(event: event)&.role || 'attendee'
  end

  def vendor_for_event?(event)
    event_participants.find_by(event: event, role: :vendor).present?
  end

  def organizer_for_event?(event)
    event_participants.find_by(event: event, role: :organizer).present?
  end

  def rsvp_status_for_event(event)
    event_participants.find_by(event: event)&.rsvp_status || 'pending'
  end
end

  # Helper methods for admin interface
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def admin?
    role == 'admin'

  # Admin safety validations
  validate :cannot_demote_last_admin
  validate :cannot_self_demote, on: :update

  def editing_self=(value)
    @editing_self = value
  end

  private

  def cannot_demote_last_admin
    if role_changed? && role_was == 'admin' && role != 'admin'
      remaining_admins = User.where(role: 'admin').where.not(id: id).count
      if remaining_admins == 0
        errors.add(:role, 'Cannot remove the last admin user')
      end
    end
  end

  def cannot_self_demote
    if defined?(@editing_self) && @editing_self && role_changed? && role_was == 'admin' && role != 'admin'
      errors.add(:role, 'You cannot remove your own admin privileges')
    end
  end

  end
