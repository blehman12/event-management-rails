#!/bin/bash

# PTC Windchill Event App - Vendor Management & Multi-Event CRUD
# Run this script from your Rails app root directory

# Store the original directory
ORIGINAL_DIR=$(pwd)

APP_NAME="${1:-ptc_windchill_event}"
cd "$APP_NAME"

set -e

echo "========================================="
echo "Adding Vendor Management & Multi-Event CRUD"
echo "========================================="

# 1. Generate EventParticipant model for role-per-event management
echo "Creating EventParticipant model..."
rails generate model EventParticipant user:references event:references role:integer rsvp_status:integer notes:text

# 2. Generate CRUD controllers for Events and Venues
echo "Generating CRUD controllers..."
rails generate controller Admin::Events index show new create edit update destroy --skip-collision-check
rails generate controller Admin::Venues index show new create edit update destroy --skip-collision-check

# 3. Update EventParticipant migration
EVENT_PARTICIPANT_MIGRATION=$(find db/migrate -name "*create_event_participants.rb" | head -1)
cat > "$EVENT_PARTICIPANT_MIGRATION" << 'EOF'
class CreateEventParticipants < ActiveRecord::Migration[7.1]
  def change
    create_table :event_participants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.integer :role, default: 0  # attendee: 0, vendor: 1, organizer: 2
      t.integer :rsvp_status, default: 0  # pending: 0, yes: 1, no: 2, maybe: 3
      t.text :notes
      t.datetime :invited_at
      t.datetime :responded_at
      t.timestamps
    end

    add_index :event_participants, [:user_id, :event_id], unique: true
    add_index :event_participants, :role
    add_index :event_participants, :rsvp_status
  end
end
EOF

# 4. Update models
echo "Updating models..."

# EventParticipant model
cat > app/models/event_participant.rb << 'EOF'
class EventParticipant < ApplicationRecord
  belongs_to :user
  belongs_to :event

  enum role: { attendee: 0, vendor: 1, organizer: 2 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }

  validates :user_id, uniqueness: { scope: :event_id }
  
  scope :vendors, -> { where(role: :vendor) }
  scope :attendees, -> { where(role: :attendee) }
  scope :organizers, -> { where(role: :organizer) }
  scope :confirmed, -> { where(rsvp_status: :yes) }

  def respond_to_rsvp!(status)
    update!(rsvp_status: status, responded_at: Time.current)
  end
end
EOF

# Update User model to use EventParticipant relationship
cat > app/models/user.rb << 'EOF'
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { attendee: 0, admin: 1 }
  enum rsvp_status: { pending: 0, yes: 1, no: 2, maybe: 3 }

  has_many :event_participants, dependent: :destroy
  has_many :events, through: :event_participants
  has_many :created_events, class_name: 'Event', foreign_key: 'creator_id'
  has_many :vendor_events, -> { where(event_participants: { role: :vendor }) }, 
           through: :event_participants, source: :event

  validates :first_name, :last_name, :phone, :company, presence: true

  scope :invited, -> { where.not(invited_at: nil) }
  scope :registered, -> { where.not(registered_at: nil) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def role_for_event(event)
    event_participants.find_by(event: event)&.role || 'attendee'
  end

  def vendor_for_event?(event)
    event_participants.find_by(event: event, role: :vendor).present?
  end

  def organizer_for_event?(event)
    event_participants.find_by(event: event, role: :organizer).present?
  end

  def rsvp_status_for_event(event)
    event_participants.find_by(event: event)&.rsvp_status || 'pending'
  end
end
EOF

# Update Event model
cat > app/models/event.rb << 'EOF'
class Event < ApplicationRecord
  belongs_to :venue
  belongs_to :creator, class_name: 'User'
  has_many :event_participants, dependent: :destroy
  has_many :users, through: :event_participants
  has_many :vendors, -> { where(event_participants: { role: :vendor }) },
           through: :event_participants, source: :user
  has_many :organizers, -> { where(event_participants: { role: :organizer }) },
           through: :event_participants, source: :user

  validates :name, :event_date, :rsvp_deadline, presence: true
  validates :max_attendees, presence: true, numericality: { greater_than: 0 }
  validate :rsvp_deadline_before_event_date

  scope :upcoming, -> { where('event_date > ?', Time.current) }
  scope :past, -> { where('event_date < ?', Time.current) }

  def attendees_count
    event_participants.yes.count
  end

  def vendors_count
    event_participants.vendor.count
  end

  def rsvp_open?
    Time.current <= rsvp_deadline
  end

  def spots_remaining
    max_attendees - attendees_count
  end

  def days_until_deadline
    return 0 if rsvp_deadline < Time.current
    ((rsvp_deadline - Time.current) / 1.day).ceil
  end

  def add_participant(user, role: :attendee)
    event_participants.find_or_create_by(user: user) do |participant|
      participant.role = role
      participant.invited_at = Time.current
    end
  end

  private

  def rsvp_deadline_before_event_date
    return unless rsvp_deadline && event_date
    
    if rsvp_deadline >= event_date
      errors.add(:rsvp_deadline, "must be before event date")
    end
  end
end
EOF

# Update Venue model with better validations
cat > app/models/venue.rb << 'EOF'
class Venue < ApplicationRecord
  has_many :events, dependent: :destroy
  
  validates :name, :address, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :name, uniqueness: true

  scope :available_for_date, ->(date) { 
    where.not(id: Event.where(event_date: date.beginning_of_day..date.end_of_day).select(:venue_id))
  }

  def full_address
    "#{name}, #{address}"
  end

  def events_count
    events.count
  end

  def upcoming_events
    events.upcoming.order(:event_date)
  end
end
EOF

# 5. Update Admin Events Controller with full CRUD
cat > app/controllers/admin/events_controller.rb << 'EOF'
class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.includes(:venue, :creator).order(:event_date)
    @upcoming_events = @events.upcoming
    @past_events = @events.past
  end

  def show
    @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
    @vendors = @participants.vendor
    @attendees = @participants.attendee
    @organizers = @participants.organizer
  end

  def new
    @event = Event.new
    @venues = Venue.all.order(:name)
  end

  def create
    @event = Event.new(event_params)
    @event.creator = current_user

    if @event.save
      # Add creator as organizer
      @event.add_participant(current_user, role: :organizer)
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
EOF

# 6. Update Admin Venues Controller with full CRUD
cat > app/controllers/admin/venues_controller.rb << 'EOF'
class Admin::VenuesController < Admin::BaseController
  before_action :set_venue, only: [:show, :edit, :update, :destroy]

  def index
    @venues = Venue.includes(:events).order(:name)
  end

  def show
    @upcoming_events = @venue.upcoming_events
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
    if @venue.events.any?
      redirect_to admin_venues_path, alert: 'Cannot delete venue with existing events.'
    else
      @venue.destroy
      redirect_to admin_venues_path, notice: 'Venue was successfully deleted.'
    end
  end

  private

  def set_venue
    @venue = Venue.find(params[:id])
  end

  def venue_params
    params.require(:venue).permit(:name, :address, :description, :capacity, :contact_info)
  end
end
EOF

# 7. Add EventParticipants controller for managing participants
cat > app/controllers/admin/event_participants_controller.rb << 'EOF'
class Admin::EventParticipantsController < Admin::BaseController
  before_action :set_event
  before_action :set_participant, only: [:show, :update, :destroy]

  def index
    @participants = @event.event_participants.includes(:user).order(:role, 'users.last_name')
    @users = User.where.not(id: @event.event_participants.select(:user_id)).order(:last_name)
  end

  def create
    @participant = @event.event_participants.build(participant_params)
    @participant.invited_at = Time.current

    if @participant.save
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant added successfully.'
    else
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error adding participant.'
    end
  end

  def update
    if @participant.update(participant_params)
      redirect_to admin_event_event_participants_path(@event), 
                  notice: 'Participant updated successfully.'
    else
      redirect_to admin_event_event_participants_path(@event), 
                  alert: 'Error updating participant.'
    end
  end

  def destroy
    @participant.destroy
    redirect_to admin_event_event_participants_path(@event), 
                notice: 'Participant removed successfully.'
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_participant
    @participant = @event.event_participants.find(params[:id])
  end

  def participant_params
    params.require(:event_participant).permit(:user_id, :role, :rsvp_status, :notes)
  end
end
EOF

# 8. Update routes
cat > config/routes.rb << 'EOF'
Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'

  namespace :admin do
    root 'dashboard#index'
    resources :users
    resources :venues
    resources :events do
      resources :event_participants, except: [:new, :edit]
    end
  end

  get 'dashboard', to: 'dashboard#index'
  patch 'rsvp/:status', to: 'rsvp#update', as: :rsvp
end
EOF

# 9. Update dashboard controller to work with new event system
cat > app/controllers/dashboard_controller.rb << 'EOF'
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
EOF

# 10. Update RSVP controller to work with EventParticipant
cat > app/controllers/rsvp_controller.rb << 'EOF'
class RsvpController < ApplicationController
  before_action :authenticate_user!

  def update
    @event = Event.find(params[:event_id]) if params[:event_id]
    @event ||= Event.upcoming.first
    
    return redirect_to dashboard_path, alert: "Event not found." unless @event
    
    if @event.rsvp_open?
      participant = @event.event_participants.find_or_create_by(user: current_user) do |p|
        p.role = :attendee
        p.invited_at = Time.current
      end
      
      participant.respond_to_rsvp!(params[:status])
      redirect_to dashboard_path, notice: "RSVP updated!"
    else
      redirect_to dashboard_path, alert: "RSVP deadline has passed."
    end
  end
end
EOF

# Run migrations
echo "Running migrations..."
rails db:migrate

# Return to original directory
cd "$ORIGINAL_DIR"

echo ""
echo "SUCCESS! Vendor management and multi-event CRUD implemented!"
echo ""
echo "New Features Added:"
echo "- EventParticipant model for role-per-event management"
echo "- Full CRUD for Events and Venues in admin"
echo "- Vendor role management per event"
echo "- Enhanced participant management"
echo ""
echo "Next: Create admin views for the new functionality"