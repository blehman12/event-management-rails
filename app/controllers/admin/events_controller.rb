require 'csv'

class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [:show, :edit, :update, :destroy, :participants, :add_participant, :export_participants, :bulk_invite]
  before_action :load_venues, only: [:new, :create, :edit, :update]
  before_action :load_users, only: [:new, :create, :edit, :update]

  def index
    @events = Event.includes(:venue, :creator, :event_participants)
                   .order(:event_date)
                   .page(params[:page])
                   .per(20)
  end

  def show
    @participants = @event.event_participants.includes(:user)
    
    # Split participants by role for the view
    @organizers = @participants.where(role: 'organizer')
    @vendors = @participants.where(role: 'vendor') 
    @attendees = @participants.where(role: 'attendee')
    
    @stats = {
      total_participants: @participants.count,
      yes_responses: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:yes] }).count,
      no_responses: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:no] }).count,
      maybe_responses: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:maybe] }).count,
      pending_responses: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:pending] }).count,
      checked_in: @participants.where.not(checked_in_at: nil).count
    }
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)
    @event.creator = current_user

    if @event.save
      redirect_to admin_event_path(@event), notice: 'Event created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @event set by before_action
    # @venues and @users loaded by before_action
  end

  def update
    if @event.update(event_params)
      redirect_to admin_event_path(@event), notice: 'Event updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to admin_events_path, notice: 'Event deleted successfully.'
  end

  def participants
    @participants = @event.event_participants.includes(:user)
    
    @participant_counts = {
      total: @participants.count,
      yes: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:yes] }).count,
      no: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:no] }).count,
      maybe: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:maybe] }).count,
      pending: @participants.joins(:user).where(users: { rsvp_status: User.rsvp_statuses[:pending] }).count
    }
    
    # Provide users for the dropdown (exclude existing participants)
    @users = User.where.not(id: @participants.select(:user_id)).order(:first_name, :last_name)
  end

  def add_participant
    @participant = @event.event_participants.build(participant_params)
    
    if @participant.save
      redirect_to participants_admin_event_path(@event), notice: 'Participant added successfully.'
    else
      redirect_to participants_admin_event_path(@event), alert: 'Failed to add participant.'
    end
  end

  def bulk_invite
    user_ids = params[:user_ids] || []
    
    if user_ids.empty?
      redirect_to admin_event_path(@event), alert: 'No users selected for invitation.'
      return
    end

    success_count = 0
    user_ids.each do |user_id|
      user = User.find(user_id)
      participant = @event.event_participants.find_or_initialize_by(user: user)
      
      if participant.new_record?
        participant.role = 'attendee'
        participant.rsvp_status = 'pending'
        participant.invited_at = Time.current
        if participant.save
          success_count += 1
          # TODO: Send invitation email
        end
      end
    end

    redirect_to admin_event_path(@event), 
                notice: "Successfully invited #{success_count} users to the event."
  end

  def export_participants
    @participants = @event.event_participants.includes(:user)

    respond_to do |format|
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ['Name', 'Email', 'Company', 'Phone', 'RSVP Status', 'Role', 'Checked In', 'Check-in Time']
          
          @participants.each do |participant|
            csv << [
              "#{participant.user.first_name} #{participant.user.last_name}",
              participant.user.email,
              participant.user.company,
              participant.user.phone,
              participant.user.rsvp_status.humanize,
              participant.role.humanize,
              participant.checked_in? ? 'Yes' : 'No',
              participant.checked_in_at&.strftime('%m/%d/%Y %I:%M %p')
            ]
          end
        end

        send_data csv_data, 
                  filename: "#{@event.name.parameterize}-participants-#{Date.current}.csv",
                  type: 'text/csv'
      end
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def load_venues
    @venues = Venue.order(:name)
    
    if @venues.empty?
      flash.now[:warning] = "No venues available. Please create a venue first."
    end
  end

  def load_users
    @users = User.where(role: 'attendee').order(:first_name, :last_name)
  end

  def participant_params
    params.require(:event_participant).permit(:user_id, :role)
  end

  def event_params
    params.require(:event).permit(
      :name,
      :description,
      :venue_id,
      :event_date,
      :start_time,
      :end_time,
      :max_attendees,
      :rsvp_deadline,
      custom_questions: []
    )
  end
end