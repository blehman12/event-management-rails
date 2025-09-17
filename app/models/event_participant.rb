class EventParticipant < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :event
  belongs_to :checked_in_by, class_name: 'User', optional: true

  # Enums
  enum role: { attendee: 0, vendor: 1, organizer: 2 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }
  enum check_in_method: { qr_code: 0, manual: 1, bulk: 2 }

  # Validations
  validates :user_id, uniqueness: { scope: :event_id }
  validates :qr_code_token, uniqueness: true, allow_nil: true

  # Serialization for custom RSVP answers (fixed deprecation)
  serialize :rsvp_answers, coder: JSON

  # Callbacks
  before_save :ensure_rsvp_answers_hash
  after_create :generate_qr_code_token

  # Scopes
  scope :vendors, -> { where(role: :vendor) }
  scope :attendees, -> { where(role: :attendee) }
  scope :organizers, -> { where(role: :organizer) }
  scope :confirmed, -> { where(rsvp_status: :yes) }
  scope :checked_in, -> { where.not(checked_in_at: nil) }
  scope :not_checked_in, -> { where(checked_in_at: nil) }

  # Check-in related methods
  def checked_in?
    checked_in_at.present?
  end

  def check_in!(method: :qr_code, checked_in_by: nil)
    update!(
      checked_in_at: Time.current,
      check_in_method: method,
      checked_in_by: checked_in_by
    )
  end

  def undo_checkin!
    update!(
      checked_in_at: nil,
      check_in_method: nil,
      checked_in_by: nil
    )
  end

  # QR Code methods
  def generate_qr_code_token
    return if qr_code_token.present?
    
    loop do
      token = SecureRandom.urlsafe_base64(16)
      if EventParticipant.where(qr_code_token: token).none?
        self.qr_code_token = token
        save! if persisted?
        break
      end
    end
  end

  def qr_code_data
  return nil unless qr_code_token.present?
  
  # For development, use your actual IP address or ngrok URL
  # For production, this should be your domain name
  
  # Option 1: Use your local network IP (find with `ipconfig` or `ifconfig`)
  # host = '192.168.1.100:3000'  # Replace with your actual IP
  
  # Option 2: For now, use localhost:3000 but note it only works on same machine
  host = 'localhost:3000'
  
  # Option 3: For testing with phones, use ngrok (recommended)
  # host = 'your-ngrok-url.ngrok.io'
  
  # Generate the check-in URL for QR codes
  "http://#{host}/checkin/verify?token=#{qr_code_token}&event=#{event_id}&participant=#{id}"
end

# For production deployment, you'd want:
# def qr_code_data
#   return nil unless qr_code_token.present?
#   
#   host = Rails.application.config.action_mailer.default_url_options[:host]
#   protocol = Rails.application.config.force_ssl? ? 'https' : 'http'
#   
#   "#{protocol}://#{host}/checkin/verify?token=#{qr_code_token}&event=#{event_id}&participant=#{id}"
# end

  def rsvp_status_text
    case rsvp_status
    when 'yes', 1
      'Attending'
    when 'maybe', 3
      'Maybe'
    when 'no', 2
      'Not Attending'
    when 'pending', 0
      'Pending'
    else
      'No Response'
    end
  end

  def has_custom_answers?
    rsvp_answers.present? && rsvp_answers.any? { |k, v| v.present? }
  end

  def check_in_status_text
    if checked_in?
      "Checked in #{checked_in_at.strftime('%m/%d/%Y at %I:%M %p')}"
    else
      'Not checked in'
    end
  end

  def check_in_method_text
    case check_in_method
    when 'qr_code'
      'QR Code'
    when 'manual'
      'Manual Entry'
    when 'bulk'
      'Bulk Check-in'
    else
      'Unknown'
    end
  end

  private

  def ensure_rsvp_answers_hash
    self.rsvp_answers = {} if rsvp_answers.blank?
  end
end