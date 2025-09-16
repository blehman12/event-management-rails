#!/bin/bash

# PTC Windchill Event App - Fix Admin Controllers
# Run this script from your Rails app root directory after running admin views script

# Store the original directory
ORIGINAL_DIR=$(pwd)

APP_NAME="${1:-ptc_windchill_event}"
cd "$APP_NAME"

set -e

echo "========================================="
echo "Fixing Admin Controllers"
echo "========================================="

# 1. Create Admin::BaseController if it doesn't exist
echo "Creating Admin::BaseController..."
mkdir -p app/controllers/admin

cat > app/controllers/admin/base_controller.rb << 'BASE_CONTROLLER_EOF'
class Admin::BaseController < ApplicationController
  before_action :ensure_admin
  
  private
  
  def ensure_admin
    redirect_to root_path, alert: "Access denied." unless current_user&.role == 'admin'
  end
end
BASE_CONTROLLER_EOF

# 2. Fix Admin::EventsController
echo "Fixing Admin::EventsController..."
cat > app/controllers/admin/events_controller.rb << 'EVENTS_CONTROLLER_EOF'
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
EVENTS_CONTROLLER_EOF

# 3. Fix Admin::VenuesController
echo "Fixing Admin::VenuesController..."
cat > app/controllers/admin/venues_controller.rb << 'VENUES_CONTROLLER_EOF'
class Admin::VenuesController < Admin::BaseController
  before_action :set_venue, only: [:show, :edit, :update, :destroy]
  
  def index
    @venues = Venue.includes(:events).order(:name)
  end
  
  def show
    @upcoming_events = @venue.events.where('event_date >= ?', Time.current).order(:event_date)
  end
  
  def new
    @venue = Venue.new
  end
  
  def create
    @venue = Venue.new(venue_params)
    
    if @venue.save
      redirect_to admin_venue_path(@venue), notice: 'Venue was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @venue.update(venue_params)
      redirect_to admin_venue_path(@venue), notice: 'Venue was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    if @venue.events.empty?
      @venue.destroy
      redirect_to admin_venues_path, notice: 'Venue was successfully deleted.'
    else
      redirect_to admin_venue_path(@venue), alert: 'Cannot delete venue with existing events.'
    end
  end
  
  private
  
  def set_venue
    @venue = Venue.find(params[:id])
  end
  
  def venue_params
    params.require(:venue).permit(:name, :address, :capacity, :description, :contact_info)
  end
end
VENUES_CONTROLLER_EOF

# 4. Fix Admin::UsersController
echo "Fixing Admin::UsersController..."
cat > app/controllers/admin/users_controller.rb << 'USERS_CONTROLLER_EOF'
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  
  def index
    @users = User.order(:last_name, :first_name)
  end
  
  def show
  end
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(user_params)
    
    if @user.save
      redirect_to admin_user_path(@user), notice: 'User was successfully created.'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    user_update_params = user_params
    # Remove password fields if they're blank
    if user_update_params[:password].blank?
      user_update_params.delete(:password)
      user_update_params.delete(:password_confirmation)
    end
    
    if @user.update(user_update_params)
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: 'Cannot delete your own account.'
    else
      @user.destroy
      redirect_to admin_users_path, notice: 'User was successfully deleted.'
    end
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :company, 
                                 :phone, :role, :password, :password_confirmation, 
                                 :text_capable)
  end
end
USERS_CONTROLLER_EOF

# 5. Fix Admin::EventParticipantsController
echo "Fixing Admin::EventParticipantsController..."
cat > app/controllers/admin/event_participants_controller.rb << 'EVENT_PARTICIPANTS_CONTROLLER_EOF'
class Admin::EventParticipantsController < Admin::BaseController
  before_action :set_event
  before_action :set_participant, only: [:update, :destroy]
  
  def index
    @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
    @users = User.where.not(id: @event.event_participants.select(:user_id)).order(:last_name, :first_name)
  end
  
  def create
    @participant = @event.event_participants.build(participant_params)
    
    if @participant.save
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant was successfully added.'
    else
      @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
      @users = User.where.not(id: @event.event_participants.select(:user_id)).order(:last_name, :first_name)
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error adding participant: ' + @participant.errors.full_messages.join(', ')
    end
  end
  
  def update
    if @participant.update(participant_update_params)
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant role was successfully updated.'
    else
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error updating participant.'
    end
  end
  
  def destroy
    @participant.destroy
    redirect_to admin_event_event_participants_path(@event), 
                notice: 'Participant was successfully removed.'
  end
  
  private
  
  def set_event
    @event = Event.find(params[:event_id])
  end
  
  def set_participant
    @participant = @event.event_participants.find(params[:id])
  end
  
  def participant_params
    params.require(:event_participant).permit(:user_id, :role, :notes)
  end
  
  def participant_update_params
    params.require(:event_participant).permit(:role, :notes)
  end
end
EVENT_PARTICIPANTS_CONTROLLER_EOF

# 6. Fix Admin::DashboardController
echo "Fixing Admin::DashboardController..."
cat > app/controllers/admin/dashboard_controller.rb << 'DASHBOARD_CONTROLLER_EOF'
class Admin::DashboardController < Admin::BaseController
  def index
    # Dashboard stats and data
  end
end
DASHBOARD_CONTROLLER_EOF

# 7. Update routes if needed
echo "Checking admin routes..."
if ! grep -q "namespace :admin" config/routes.rb; then
  echo "Adding admin routes..."
  cat >> config/routes.rb << 'ROUTES_EOF'

  namespace :admin do
    root 'dashboard#index'
    resources :events do
      resources :event_participants, path: 'participants'
    end
    resources :venues
    resources :users
  end
ROUTES_EOF
fi

# 8. Add helper methods to models if they don't exist
echo "Adding helper methods to models..."

# Add methods to Event model
echo "Adding methods to Event model..."
cat >> app/models/event.rb << 'EVENT_METHODS_EOF'

  # Helper methods for admin interface
  def rsvp_open?
    rsvp_deadline.present? && rsvp_deadline > Time.current
  end
  
  def spots_remaining
    max_attendees - attendees_count
  end
  
  def attendees_count
    event_participants.where(rsvp_status: 'yes').count
  end
EVENT_METHODS_EOF

# Add methods to Venue model
echo "Adding methods to Venue model..."
cat >> app/models/venue.rb << 'VENUE_METHODS_EOF'

  # Helper methods for admin interface
  def events_count
    events.count
  end
  
  def upcoming_events
    events.where('event_date >= ?', Time.current)
  end
  
  def full_address
    address
  end
VENUE_METHODS_EOF

# Add methods to User model
echo "Adding methods to User model..."
cat >> app/models/user.rb << 'USER_METHODS_EOF'

  # Helper methods for admin interface
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def admin?
    role == 'admin'
  end
USER_METHODS_EOF

# Return to original directory
cd "$ORIGINAL_DIR"

echo ""
echo "SUCCESS! Admin controllers have been fixed!"
echo ""
echo "Fixed Issues:"
echo "- Created Admin::BaseController with proper authorization"
echo "- Fixed all admin controllers to use role-based auth"
echo "- Removed non-existent method calls"
echo "- Added missing helper methods to models"
echo "- Fixed EventParticipant creation logic"
echo ""
echo "Test the admin interface at: http://localhost:3000/admin"
echo "Login with: admin@ptc.com / password123"