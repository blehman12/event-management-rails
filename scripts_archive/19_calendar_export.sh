#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Setting up calendar export functionality..."

cd "$APP_NAME"

# Add icalendar gem if not already added
if ! grep -q "gem 'icalendar'" Gemfile; then
  echo "gem 'icalendar'" >> Gemfile
  bundle install
fi

# Generate Calendar Controller
rails generate controller Calendar export

cat > app/controllers/calendar_controller.rb << 'CALENDAR_CONTROLLER_EOF'
class CalendarController < ApplicationController
  before_action :authenticate_user!

  def export
    @event = Event.find(params[:event_id]) if params[:event_id]
    @user_events = current_user.events.upcoming

    respond_to do |format|
      format.ics do
        calendar = build_calendar
        render plain: calendar.to_ical, content_type: 'text/calendar'
      end
    end
  end

  private

  def build_calendar
    cal = Icalendar::Calendar.new
    cal.prodid = '-//PTC Windchill Events//Event Calendar//EN'
    
    events_to_export = @event ? [@event] : @user_events
    
    events_to_export.each do |event|
      participant = current_user.event_participants.find_by(event: event)
      next if participant&.rsvp_status == 'no'
      
      cal.event do |e|
        e.uid = "event-#{event.id}@ptcwindchill-events.com"
        e.dtstart = event.event_date
        e.dtend = calculate_end_time(event)
        e.summary = event.name
        e.description = build_description(event, participant)
        e.location = event.venue.full_address
        e.organizer = "mailto:#{event.creator.email}"
        
        # Add reminder alarms
        e.alarm do |a|
          a.action = 'DISPLAY'
          a.description = 'Event reminder'
          a.trigger = '-PT1H'  # 1 hour before
        end
        
        e.alarm do |a|
          a.action = 'DISPLAY'
          a.description = 'Event reminder'
          a.trigger = '-P1D'   # 1 day before
        end
      end
    end
    
    cal
  end

  def calculate_end_time(event)
    if event.end_time && event.start_time
      event.event_date + (event.end_time.seconds_since_midnight - event.start_time.seconds_since_midnight).seconds
    else
      event.event_date + 2.hours  # Default 2 hour duration
    end
  end

  def build_description(event, participant)
    description = []
    description << event.description if event.description.present?
    description << ""
    description << "Your Status: #{participant&.rsvp_status&.humanize || 'Not responded'}"
    description << "Your Role: #{participant&.role&.humanize || 'Attendee'}" if participant&.role != 'attendee'
    description << ""
    description << "RSVP Deadline: #{event.rsvp_deadline.strftime('%B %d, %Y at %I:%M %p')}"
    description << "Capacity: #{event.max_attendees} people"
    description << ""
    description << "Manage your RSVP: #{root_url}"
    
    description.join("\n")
  end
end
CALENDAR_CONTROLLER_EOF

# Add routes for calendar export
cat >> config/routes.rb.tmp << 'CALENDAR_ROUTES_EOF'
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
  
  # Calendar export routes
  get 'calendar/export', to: 'calendar#export', defaults: { format: 'ics' }
  get 'calendar/export/:event_id', to: 'calendar#export', defaults: { format: 'ics' }, as: :export_event_calendar
end
CALENDAR_ROUTES_EOF

# Replace routes file
mv config/routes.rb.tmp config/routes.rb

# Add calendar export links to dashboard
cat >> app/views/dashboard/index.html.erb << 'CALENDAR_LINKS_EOF'

    <div class="mt-3">
      <div class="d-grid gap-2 d-md-flex">
        <%= link_to "📅 Add to Calendar", calendar_export_path(format: :ics), 
                    class: "btn btn-outline-primary btn-sm", 
                    title: "Download calendar file for all your events" %>
        <% if @current_event %>
          <%= link_to "📅 Add This Event", export_event_calendar_path(@current_event, format: :ics), 
                      class: "btn btn-outline-secondary btn-sm",
                      title: "Download calendar file for this event only" %>
        <% end %>
      </div>
    </div>
CALENDAR_LINKS_EOF

# Update User model to track calendar exports
rails generate migration AddCalendarExportedToUsers calendar_exported:boolean

# Update the migration
CALENDAR_MIGRATION=$(find db/migrate -name "*add_calendar_exported_to_users.rb" | head -1)
cat > "$CALENDAR_MIGRATION" << 'CALENDAR_MIGRATION_EOF'
class AddCalendarExportedToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :calendar_exported, :boolean, default: false
    add_index :users, :calendar_exported
  end
end
CALENDAR_MIGRATION_EOF

# Update controller to track exports
cat >> app/controllers/calendar_controller.rb << 'TRACK_EXPORT_EOF'

  after_action :track_calendar_export

  def track_calendar_export
    current_user.update(calendar_exported: true) unless current_user.calendar_exported?
  end
TRACK_EXPORT_EOF

echo "Calendar export functionality setup completed!"
echo "Users can now export events to their calendar applications"
