class CheckinController < ApplicationController
  def index
    # Main check-in interface
    redirect_to checkin_scan_path
  end
  
  def scan
    # QR code scanning interface (mobile-friendly)
  end
  
  def manual
    # Manual name lookup for check-in
    @events = Event.where('event_date >= ?', Date.current).order(:event_date)
  end
  
  def verify
    # Handle QR code verification
    @token = params[:token]
    @event_id = params[:event]
    @participant_id = params[:participant]
    
    # Find the participant by token for security
    @participant = EventParticipant.joins(:event)
                                   .where(qr_code_token: @token, 
                                          event_id: @event_id, 
                                          id: @participant_id)
                                   .first
    
    if @participant
      @event = @participant.event
      @user = @participant.user
      
      # Check if already checked in
      if @participant.checked_in?
        @message = "Already checked in at #{@participant.checked_in_at.strftime('%I:%M %p')}"
        @status = 'already_checked_in'
      else
        @message = "Ready to check in"
        @status = 'ready'
      end
    else
      @message = "Invalid QR code or check-in link"
      @status = 'invalid'
    end
  end
  
  def process_checkin
    # Process the actual check-in
    token = params[:token]
    event_id = params[:event_id]
    participant_id = params[:participant_id]
    
    # Find participant securely
    participant = EventParticipant.joins(:event)
                                  .where(qr_code_token: token,
                                         event_id: event_id,
                                         id: participant_id)
                                  .first
    
    if participant && !participant.checked_in?
      # Perform check-in
      participant.check_in!(method: :qr_code)
      
      redirect_to checkin_success_path(participant.id), 
                  notice: "Successfully checked in!"
    elsif participant&.checked_in?
      redirect_to checkin_success_path(participant.id),
                  alert: "Already checked in at #{participant.checked_in_at.strftime('%I:%M %p')}"
    else
      redirect_to checkin_path, alert: "Invalid check-in information"
    end
  end
  
  def success
    # Check-in confirmation page
    @participant = EventParticipant.find_by(id: params[:id])
    
    if @participant
      @event = @participant.event
      @user = @participant.user
    else
      redirect_to checkin_path, alert: "Check-in information not found"
    end
  end
end