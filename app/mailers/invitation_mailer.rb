class InvitationMailer < ApplicationMailer
  default from: ENV['GMAIL_USERNAME'] || 'noreply@example.com'

  def event_invitation(user, event)
    @user = user
    @event = event
    # Fix the URL generation
    @rsvp_url = "#{root_url(host: 'localhost:3000')}rsvp"
    
    mail(
      to: @user.email,
      subject: "You're invited to #{@event.name}"
    )
  end
end