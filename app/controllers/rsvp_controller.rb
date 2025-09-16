class RsvpController < ApplicationController
  before_action :authenticate_user!
  
  def update
    event = Event.find(params[:event_id]) if params[:event_id]
    event ||= Event.upcoming.first || Event.first
    
    if event.nil?
      redirect_to root_path, alert: "No event found"
      return
    end
    
    # Find or create participant record
    participant = current_user.event_participants.find_by(event: event)
    
    if participant
      # Update existing participant
      participant.update!(
        rsvp_status: params[:status],
        responded_at: Time.current
      )
      
      # ADD THIS LINE HERE:
      EventNotificationMailer.rsvp_confirmation(participant).deliver_now
      
      redirect_to root_path, notice: "RSVP updated to #{params[:status].humanize}"
    else
      # Handle legacy single-event RSVP system
      if current_user.respond_to?(:rsvp_status=)
        current_user.update!(rsvp_status: params[:status])
        current_user.update!(registered_at: Time.current) if current_user.registered_at.nil?
        redirect_to root_path, notice: "RSVP updated to #{params[:status].humanize}"
      else
        redirect_to root_path, alert: "Could not update RSVP"
      end
    end
  end
end  # <-- This was missing!