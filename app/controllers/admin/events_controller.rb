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
    params.require(:event).permit(:name, :description, :event_date, :start_time, 
                                  :end_time, :max_attendees, :rsvp_deadline, :venue_id)
  end
end
