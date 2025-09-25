class RsvpController < ApplicationController
  before_action :authenticate_user!
  
  def show
    # Handle both direct event access and fallback to latest event
    @current_event = if params[:event_id]
                       Event.find_by(id: params[:event_id])
                     else
                       Event.order(:event_date).last
                     end
    
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
    # Use find_by to avoid exceptions, with fallback to latest event
    @event = if params[:event_id].present?
               Event.find_by(id: params[:event_id])
             else
               Event.order(:event_date).last
             end
    
    unless @event
      flash[:alert] = "No event found for RSVP."
      redirect_to root_path
      return
    end
    
    # Check if RSVP deadline has passed
    if @event.rsvp_deadline && @event.rsvp_deadline < Time.current
      flash[:alert] = "RSVP deadline has passed for this event."
      redirect_to root_path
      return
    end
    
    # Validate status parameter
    valid_statuses = ['yes', 'no', 'maybe', 'pending']
    unless valid_statuses.include?(params[:status])
      flash[:alert] = "Invalid RSVP status."
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
      # Send notification email if mailer exists
      begin
        if defined?(EventNotificationMailer)
          EventNotificationMailer.rsvp_notification(
            current_user, 
            @event, 
            params[:status]
          ).deliver_now
          flash[:notice] = "RSVP updated successfully! Confirmation email sent."
        else
          flash[:notice] = "RSVP updated successfully!"
        end
      rescue => e
        Rails.logger.error "Email delivery failed: #{e.message}"
        flash[:notice] = "RSVP updated successfully! (Email notification failed)"
      end
      
      redirect_to root_path
    else
      flash[:alert] = "Failed to update RSVP: #{@participant.errors.full_messages.join(', ')}"
      redirect_to root_path
    end
  end
  
  private
  
  def rsvp_params
    params.permit(:status, :event_id, rsvp_answers: {})
  end
end