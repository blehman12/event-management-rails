class InvitationMailer < ApplicationMailer
  default from: ENV['GMAIL_USERNAME'] || 'noreply@example.com'
  
  def event_invitation(user, event)
    @user = user
    @event = event
    # Better approach using Rails URL helpers
    @rsvp_url = event_rsvp_url(@event, host: 'localhost:3000')
    
    mail(
      to: @user.email,
      subject: "You're invited to #{@event.name}"
    )
  end
end