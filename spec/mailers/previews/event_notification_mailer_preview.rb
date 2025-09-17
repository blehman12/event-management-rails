# Preview all emails at http://localhost:3000/rails/mailers/event_notification_mailer_mailer
class EventNotificationMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/event_notification_mailer_mailer/rsvp_confirmation
  def rsvp_confirmation
    EventNotificationMailer.rsvp_confirmation
  end

end
