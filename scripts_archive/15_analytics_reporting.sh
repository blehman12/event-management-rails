#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Setting up analytics and reporting system..."

cd "$APP_NAME"

# Generate Reports Controller
rails generate controller Admin::Reports index rsvp_summary event_analytics user_engagement

cat > app/controllers/admin/reports_controller.rb << 'REPORTS_CONTROLLER_EOF'
class Admin::ReportsController < Admin::BaseController
  def index
    @total_events = Event.count
    @total_participants = EventParticipant.count
    @response_rate = calculate_response_rate
    @recent_activity = recent_activity_data
  end

  def rsvp_summary
    @event = Event.find(params[:event_id]) if params[:event_id]
    @events = Event.includes(:event_participants).order(:event_date)
    
    if @event
      @rsvp_data = rsvp_breakdown(@event)
      @company_breakdown = company_breakdown(@event)
      @timeline_data = response_timeline(@event)
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @rsvp_data }
      format.csv { send_rsvp_csv }
    end
  end

  def event_analytics
    @events = Event.includes(:event_participants, :venue).order(:event_date)
    @analytics_data = events_analytics_data
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics_data }
    end
  end

  def user_engagement
    @engagement_data = user_engagement_data
    @top_companies = top_companies_by_participation
    @user_stats = user_participation_stats
    
    respond_to do |format|
      format.html
      format.json { render json: @engagement_data }
    end
  end

  private

  def calculate_response_rate
    total_participants = EventParticipant.count
    responded_participants = EventParticipant.where.not(rsvp_status: 'pending').count
    return 0 if total_participants == 0
    (responded_participants.to_f / total_participants * 100).round(1)
  end

  def recent_activity_data
    {
      new_users: User.where('created_at > ?', 7.days.ago).count,
      new_rsvps: EventParticipant.where('updated_at > ? AND rsvp_status != ?', 7.days.ago, 'pending').count,
      upcoming_events: Event.upcoming.count
    }
  end

  def rsvp_breakdown(event)
    {
      yes: event.event_participants.yes.count,
      maybe: event.event_participants.maybe.count,
      no: event.event_participants.no.count,
      pending: event.event_participants.pending.count,
      vendors: event.event_participants.vendor.count,
      organizers: event.event_participants.organizer.count
    }
  end

  def company_breakdown(event)
    event.event_participants
         .joins(:user)
         .group('users.company')
         .group(:rsvp_status)
         .count
         .transform_keys { |k| { company: k[0], status: k[1] } }
  end

  def response_timeline(event)
    event.event_participants
         .where.not(responded_at: nil)
         .group_by_day(:responded_at, last: 30)
         .group(:rsvp_status)
         .count
  end

  def events_analytics_data
    @events.map do |event|
      {
        id: event.id,
        name: event.name,
        date: event.event_date,
        venue: event.venue.name,
        capacity: event.max_attendees,
        registered: event.event_participants.count,
        confirmed: event.event_participants.yes.count,
        response_rate: event.event_participants.where.not(rsvp_status: 'pending').count.to_f / 
                      [event.event_participants.count, 1].max * 100,
        vendor_count: event.event_participants.vendor.count,
        spots_remaining: event.spots_remaining
      }
    end
  end

  def user_engagement_data
    {
      total_users: User.count,
      active_users: User.joins(:event_participants).distinct.count,
      multi_event_users: User.joins(:event_participants).group('users.id').having('COUNT(event_participants.id) > 1').count.size,
      calendar_exporters: User.where(calendar_exported: true).count
    }
  end

  def top_companies_by_participation
    User.joins(:event_participants)
        .group(:company)
        .count
        .sort_by { |_, count| -count }
        .first(10)
  end

  def user_participation_stats
    {
      average_events_per_user: EventParticipant.count.to_f / [User.count, 1].max,
      text_capable_percentage: (User.where(text_capable: true).count.to_f / [User.count, 1].max * 100).round(1),
      admin_count: User.admin.count
    }
  end

  def send_rsvp_csv
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Name', 'Email', 'Company', 'Phone', 'RSVP Status', 'Role', 'Responded At']
      
      @event.event_participants.includes(:user).each do |participant|
        csv << [
          participant.user.full_name,
          participant.user.email,
          participant.user.company,
          participant.user.phone,
          participant.rsvp_status.humanize,
          participant.role.humanize,
          participant.responded_at&.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end

    send_data csv_data, filename: "#{@event.name.parameterize}-rsvps-#{Date.current}.csv"
  end
end
REPORTS_CONTROLLER_EOF

# Create reports views
mkdir -p app/views/admin/reports

cat > app/views/admin/reports/index.html.erb << 'REPORTS_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Analytics & Reports</h2>
  <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="row mb-4">
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Total Events</h5>
        <h2 class="text-primary"><%= @total_events %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Total Participants</h5>
        <h2 class="text-success"><%= @total_participants %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Response Rate</h5>
        <h2 class="text-info"><%= @response_rate %>%</h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Active This Week</h5>
        <h2 class="text-warning"><%= @recent_activity[:new_rsvps] %></h2>
      </div>
    </div>
  </div>
</div>

<div class="row">
  <div class="col-md-6">
    <div class="card">
      <div class="card-header">
        <h5>Quick Reports</h5>
      </div>
      <div class="card-body">
        <div class="d-grid gap-2">
          <%= link_to "RSVP Summary", admin_reports_rsvp_summary_path, class: "btn btn-primary" %>
          <%= link_to "Event Analytics", admin_reports_event_analytics_path, class: "btn btn-success" %>
          <%= link_to "User Engagement", admin_reports_user_engagement_path, class: "btn btn-info" %>
        </div>
      </div>
    </div>
  </div>
  
  <div class="col-md-6">
    <div class="card">
      <div class="card-header">
        <h5>Recent Activity</h5>
      </div>
      <div class="card-body">
        <ul class="list-unstyled">
          <li><strong><%= @recent_activity[:new_users] %></strong> new users this week</li>
          <li><strong><%= @recent_activity[:new_rsvps] %></strong> new RSVPs this week</li>
          <li><strong><%= @recent_activity[:upcoming_events] %></strong> upcoming events</li>
        </ul>
      </div>
    </div>
  </div>
</div>
REPORTS_INDEX_EOF

cat > app/views/admin/reports/rsvp_summary.html.erb << 'RSVP_SUMMARY_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>RSVP Summary</h2>
  <div>
    <% if @event %>
      <%= link_to "Export CSV", admin_reports_rsvp_summary_path(@event, format: :csv), class: "btn btn-success me-2" %>
    <% end %>
    <%= link_to "Back to Reports", admin_reports_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="mb-4">
  <%= form_with url: admin_reports_rsvp_summary_path, method: :get, local: true, class: "row g-3 align-items-end" do |form| %>
    <div class="col-auto">
      <%= form.label :event_id, "Select Event", class: "form-label" %>
      <%= form.select :event_id, options_from_collection_for_select(@events, :id, :name, params[:event_id]), 
                      { prompt: "All Events" }, { class: "form-select" } %>
    </div>
    <div class="col-auto">
      <%= form.submit "Generate Report", class: "btn btn-primary" %>
    </div>
  <% end %>
</div>

<% if @event && @rsvp_data %>
  <div class="row mb-4">
    <div class="col-md-8">
      <div class="card">
        <div class="card-header">
          <h5><%= @event.name %> - RSVP Breakdown</h5>
        </div>
        <div class="card-body">
          <div class="row text-center">
            <div class="col-3">
              <h3 class="text-success"><%= @rsvp_data[:yes] %></h3>
              <p>Confirmed</p>
            </div>
            <div class="col-3">
              <h3 class="text-warning"><%= @rsvp_data[:maybe] %></h3>
              <p>Maybe</p>
            </div>
            <div class="col-3">
              <h3 class="text-danger"><%= @rsvp_data[:no] %></h3>
              <p>Declined</p>
            </div>
            <div class="col-3">
              <h3 class="text-secondary"><%= @rsvp_data[:pending] %></h3>
              <p>Pending</p>
            </div>
          </div>
          <hr>
          <div class="row text-center">
            <div class="col-6">
              <h4 class="text-info"><%= @rsvp_data[:vendors] %></h4>
              <p>Vendors</p>
            </div>
            <div class="col-6">
              <h4 class="text-primary"><%= @rsvp_data[:organizers] %></h4>
              <p>Organizers</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div class="col-md-4">
      <div class="card">
        <div class="card-header">
          <h6>Event Details</h6>
        </div>
        <div class="card-body">
          <p><strong>Date:</strong> <%= @event.event_date.strftime('%B %d, %Y') %></p>
          <p><strong>Venue:</strong> <%= @event.venue.name %></p>
          <p><strong>Capacity:</strong> <%= @event.max_attendees %></p>
          <p><strong>Registered:</strong> <%= @event.event_participants.count %></p>
          <p><strong>Response Rate:</strong> 
            <%= ((@event.event_participants.where.not(rsvp_status: 'pending').count.to_f / [@event.event_participants.count, 1].max) * 100).round(1) %>%
          </p>
        </div>
      </div>
    </div>
  </div>
<% end %>
RSVP_SUMMARY_EOF

# Add routes for reports
sed -i '/resources :bulk_users/a\    resources :reports, only: [:index] do\n      collection do\n        get :rsvp_summary\n        get :event_analytics\n        get :user_engagement\n      end\n    end' config/routes.rb

echo "Analytics and reporting system setup completed!"
