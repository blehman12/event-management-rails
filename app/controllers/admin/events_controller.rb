class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  
  def index
    @events = Event.includes(:venue, :creator).order(:event_date)
  end
  
  def show
    @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
    @vendors = @participants.where(role: 'vendor')
    @attendees = @participants.where(role: 'attendee') 
    @organizers = @participants.where(role: 'organizer')
    
    respond_to do |format|
      format.html # regular show page
      format.csv { send_csv_export }
    end
  end
  
  def new
    @event = Event.new
    @venues = Venue.all.order(:name)
  end
  
  def create
    @event = Event.new(event_params)
    @event.creator = current_user
    
    if @event.save
      # Create organizer participation record directly
      EventParticipant.create!(
        event: @event,
        user: current_user,
        role: 'organizer',
        rsvp_status: 'yes',
        responded_at: Time.current
      )
      redirect_to admin_event_path(@event), notice: 'Event was successfully created.'
    else
      @venues = Venue.all.order(:name)
      render :new
    end
  end
  
  def edit
    @venues = Venue.all.order(:name)
  end
  
  def update
    @event = Event.find(params[:id])
    
    # Clean up empty custom questions
    if params[:event][:custom_questions].present?
      params[:event][:custom_questions] = params[:event][:custom_questions].reject(&:blank?)
    end
    
    if @event.update(event_params)
      redirect_to admin_event_path(@event), notice: 'Event was successfully updated.'
    else
      @venues = Venue.all.order(:name)
      render :edit
    end
  end
  
  def destroy
    @event.destroy
    redirect_to admin_events_path, notice: 'Event was successfully deleted.'
  end
  
  private
  
  def set_event
    @event = Event.find(params[:id])
  end
  
  def event_params
    params.require(:event).permit(
      :name, :title, :description, :event_date, :start_time, :end_time,
      :venue_id, :max_attendees, :rsvp_deadline, :is_active,
      custom_questions: []
    )
  end
  
  def send_csv_export
    require 'csv'
    
    csv_data = CSV.generate(headers: true) do |csv|
      # Header row
      headers = ['Name', 'Email', 'RSVP Status', 'Response Date']
      
      # Add custom question headers
      if @event.custom_questions.present?
        headers += @event.custom_questions
      end
      
      csv << headers
      
      # Data rows
      @event.event_participants.includes(:user).each do |participant|
        row = [
          participant.user.name,
          participant.user.email,
          format_rsvp_status(participant.rsvp_status),
          participant.updated_at.strftime("%m/%d/%Y %I:%M %p")
        ]
        
        # Add custom question answers
        if @event.custom_questions.present?
          @event.custom_questions.each_with_index do |question, index|
            answer = participant.rsvp_answers&.dig("question_#{index}") || ''
            row << answer
          end
        end
        
        csv << row
      end
    end
    
    filename = "#{@event.name.parameterize}-rsvp-export-#{Date.current.strftime('%Y%m%d')}.csv"
    
    send_data csv_data, 
              filename: filename,
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end
  
  def format_rsvp_status(status)
    case status.to_s
    when 'yes', '1' then 'Attending'
    when 'maybe', '3' then 'Maybe'
    when 'no', '2' then 'Not Attending'
    else 'No Response'
    end
  end
end