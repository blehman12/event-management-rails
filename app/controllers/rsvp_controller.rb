class RsvpController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @current_event = Event.order(:event_date).last
    
    if @current_event
      @participant = EventParticipant.find_by(
        user: current_user,
        event: @current_event
      )
      
      @user_rsvp_status = @participant&.rsvp_status || 'pending'
    else
      flash[:alert] = "No events available for RSVP."
      redirect_to root_path
    end
  end
  
  def update
    @event = Event.order(:event_date).last
    
    unless @event
      flash[:alert] = "No event found for RSVP."
      redirect_to root_path
      return
    end
    
    @participant = EventParticipant.find_or_create_by(
      user: current_user,
      event: @event
    )
    
    # Update RSVP status
    @participant.rsvp_status = params[:status]
    
    # Update RSVP answers if provided
    if params[:rsvp_answers].present?
      # Clean up the answers hash
      cleaned_answers = {}
      params[:rsvp_answers].each do |key, value|
        cleaned_answers[key] = value.strip if value.present?
      end
      @participant.rsvp_answers = cleaned_answers
    end
    
    if @participant.save
      # Send notification email
      begin
        EventNotificationMailer.rsvp_notification(
          current_user, 
          @event, 
          params[:status]
        ).deliver_now
        flash[:notice] = "RSVP updated successfully! Confirmation email sent."
      rescue => e
        Rails.logger.error "Email delivery failed: #{e.message}"
        flash[:notice] = "RSVP updated successfully!"
      end
      
      redirect_to rsvp_path
    else
      flash[:alert] = "Failed to update RSVP: #{@participant.errors.full_messages.join(', ')}"
      redirect_to rsvp_path
    end
  end
end