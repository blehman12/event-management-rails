class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @events = Event.upcoming.includes(:venue).order(:event_date)
    @current_event = @events.first
    @my_events = current_user.events.upcoming.order(:event_date)
    
    if @current_event
      @my_participation = current_user.event_participants.find_by(event: @current_event)
      @user_rsvp_status = @my_participation&.rsvp_status || 'pending'
      @deadline_passed = @current_event.rsvp_deadline < Time.current
      @my_role = @my_participation&.role || 'attendee'
    end
  end
end
