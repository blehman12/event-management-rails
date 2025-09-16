#!/bin/bash

# PTC Windchill Event App - Admin Views for Vendor Management & Multi-Event CRUD
# Run this script from your Rails app root directory after running 09_vendor_management_script.sh

# Store the original directory
ORIGINAL_DIR=$(pwd)

APP_NAME="${1:-ptc_windchill_event}"
cd "$APP_NAME"

set -e

echo "========================================="
echo "Creating Admin Views for Multi-Event & Vendor Management"
echo "========================================="

# Ensure admin view directories exist
echo "Creating admin view directories..."
mkdir -p app/views/admin/dashboard
mkdir -p app/views/admin/events
mkdir -p app/views/admin/venues
mkdir -p app/views/admin/event_participants
mkdir -p app/views/admin/users

# 1. Update Admin Dashboard to show event stats
echo "Updating admin dashboard..."
cat > app/views/admin/dashboard/index.html.erb << 'ADMIN_DASH_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Admin Dashboard</h2>
  <%= link_to "Back to Main Site", root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="row mb-4">
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Total Users</h6>
        <h3 class="text-primary"><%= User.count %></h3>
      </div>
    </div>
  </div>
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Total Events</h6>
        <h3 class="text-info"><%= Event.count %></h3>
      </div>
    </div>
  </div>
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Total Venues</h6>
        <h3 class="text-warning"><%= Venue.count %></h3>
      </div>
    </div>
  </div>
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Participants</h6>
        <h3 class="text-success"><%= EventParticipant.count %></h3>
      </div>
    </div>
  </div>
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Vendors</h6>
        <h3 class="text-danger"><%= EventParticipant.vendor.count %></h3>
      </div>
    </div>
  </div>
  <div class="col-md-2">
    <div class="card text-center">
      <div class="card-body">
        <h6>Confirmed</h6>
        <h3 class="text-secondary"><%= EventParticipant.yes.count %></h3>
      </div>
    </div>
  </div>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>Quick Actions</h5>
      </div>
      <div class="card-body">
        <div class="row">
          <div class="col-md-4 mb-3">
            <%= link_to "Manage Users", admin_users_path, class: "btn btn-primary w-100" %>
          </div>
          <div class="col-md-4 mb-3">
            <%= link_to "Manage Events", admin_events_path, class: "btn btn-success w-100" %>
          </div>
          <div class="col-md-4 mb-3">
            <%= link_to "Manage Venues", admin_venues_path, class: "btn btn-info w-100" %>
          </div>
        </div>
        <div class="row">
          <div class="col-md-6">
            <%= link_to "New Event", new_admin_event_path, class: "btn btn-outline-success w-100" %>
          </div>
          <div class="col-md-6">
            <%= link_to "New Venue", new_admin_venue_path, class: "btn btn-outline-info w-100" %>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Recent Activity</h6>
      </div>
      <div class="card-body">
        <% Event.order(created_at: :desc).limit(5).each do |event| %>
          <div class="mb-2">
            <small class="text-muted"><%= event.created_at.strftime("%m/%d") %></small><br>
            <%= link_to event.name, admin_event_path(event), class: "text-decoration-none" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
ADMIN_DASH_EOF

# 2. Create Events index view
echo "Creating events index view..."
cat > app/views/admin/events/index.html.erb << 'EVENTS_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Events</h2>
  <div>
    <%= link_to "New Event", new_admin_event_path, class: "btn btn-success me-2" %>
    <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="card">
  <div class="card-body">
    <% if @events.any? %>
      <div class="table-responsive">
        <table class="table table-striped">
          <thead>
            <tr>
              <th>Event Name</th>
              <th>Date</th>
              <th>Venue</th>
              <th>Attendees</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @events.each do |event| %>
              <tr>
                <td>
                  <%= link_to event.name, admin_event_path(event), class: "fw-bold text-decoration-none" %>
                </td>
                <td><%= event.event_date&.strftime("%b %d, %Y") %></td>
                <td><%= event.venue&.name %></td>
                <td>
                  <span class="badge bg-primary"><%= event.attendees_count %> / <%= event.max_attendees %></span>
                </td>
                <td>
                  <% if event.rsvp_open? %>
                    <span class="badge bg-success">Open</span>
                  <% else %>
                    <span class="badge bg-danger">Closed</span>
                  <% end %>
                </td>
                <td>
                  <div class="btn-group btn-group-sm">
                    <%= link_to "View", admin_event_path(event), class: "btn btn-outline-primary" %>
                    <%= link_to "Edit", edit_admin_event_path(event), class: "btn btn-outline-secondary" %>
                    <%= link_to "Participants", admin_event_event_participants_path(event), class: "btn btn-outline-info" %>
                    <%= link_to "Delete", admin_event_path(event), method: :delete, 
                                confirm: "Are you sure? This will remove all participants.", 
                                class: "btn btn-outline-danger" %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div class="text-center py-5">
        <h4 class="text-muted">No events found</h4>
        <p class="text-muted">Create your first event to get started.</p>
        <%= link_to "Create Event", new_admin_event_path, class: "btn btn-success" %>
      </div>
    <% end %>
  </div>
</div>
EVENTS_INDEX_EOF

# 3. Create Event show view
echo "Creating event show view..."
cat > app/views/admin/events/show.html.erb << 'EVENT_SHOW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2><%= @event.name %></h2>
  <div>
    <%= link_to "Edit Event", edit_admin_event_path(@event), class: "btn btn-warning me-2" %>
    <%= link_to "Manage Participants", admin_event_event_participants_path(@event), class: "btn btn-info me-2" %>
    <%= link_to "Back to Events", admin_events_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card mb-4">
      <div class="card-header">
        <h5>Event Details</h5>
      </div>
      <div class="card-body">
        <div class="row">
          <div class="col-md-6">
            <p><strong>Date:</strong> <%= @event.event_date&.strftime("%A, %B %d, %Y") %></p>
            <p><strong>Time:</strong> <%= @event.start_time&.strftime("%I:%M %p") %> - <%= @event.end_time&.strftime("%I:%M %p") %></p>
            <p><strong>Venue:</strong> <%= link_to @event.venue.name, admin_venue_path(@event.venue) %></p>
            <p><strong>Capacity:</strong> <%= @event.max_attendees %> people</p>
          </div>
          <div class="col-md-6">
            <p><strong>RSVP Deadline:</strong> <%= @event.rsvp_deadline&.strftime("%B %d, %Y") %></p>
            <p><strong>Created by:</strong> <%= @event.creator.full_name %></p>
            <p><strong>Status:</strong> 
              <% if @event.rsvp_open? %>
                <span class="badge bg-success">RSVP Open</span>
              <% else %>
                <span class="badge bg-danger">RSVP Closed</span>
              <% end %>
            </p>
            <p><strong>Spots Remaining:</strong> <%= @event.spots_remaining %></p>
          </div>
        </div>
        <% if @event.description.present? %>
          <div class="mt-3">
            <strong>Description:</strong>
            <p><%= simple_format(@event.description) %></p>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card mb-3">
      <div class="card-header">
        <h6>Participation Summary</h6>
      </div>
      <div class="card-body">
        <div class="row text-center">
          <div class="col-6">
            <h4 class="text-success"><%= @participants.yes.count %></h4>
            <small>Confirmed</small>
          </div>
          <div class="col-6">
            <h4 class="text-warning"><%= @participants.maybe.count %></h4>
            <small>Maybe</small>
          </div>
        </div>
        <div class="row text-center mt-2">
          <div class="col-6">
            <h4 class="text-danger"><%= @participants.no.count %></h4>
            <small>Declined</small>
          </div>
          <div class="col-6">
            <h4 class="text-secondary"><%= @participants.pending.count %></h4>
            <small>Pending</small>
          </div>
        </div>
      </div>
    </div>
    
    <div class="card">
      <div class="card-header">
        <h6>Roles</h6>
      </div>
      <div class="card-body">
        <p><strong>Organizers:</strong> <%= @organizers.count %></p>
        <p><strong>Vendors:</strong> <%= @vendors.count %></p>
        <p><strong>Attendees:</strong> <%= @attendees.count %></p>
      </div>
    </div>
  </div>
</div>

<div class="row">
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Organizers</h6>
      </div>
      <div class="card-body">
        <% @organizers.each do |participant| %>
          <div class="mb-2">
            <strong><%= participant.user.full_name %></strong><br>
            <small class="text-muted"><%= participant.user.company %></small>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Vendors</h6>
      </div>
      <div class="card-body">
        <% if @vendors.any? %>
          <% @vendors.each do |participant| %>
            <div class="mb-2">
              <strong><%= participant.user.full_name %></strong><br>
              <small class="text-muted"><%= participant.user.company %></small>
              <br>
              <span class="badge bg-<%= participant.rsvp_status == 'yes' ? 'success' : 'secondary' %>">
                <%= participant.rsvp_status.humanize %>
              </span>
            </div>
          <% end %>
        <% else %>
          <p class="text-muted">No vendors assigned</p>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Recent RSVPs</h6>
      </div>
      <div class="card-body">
        <% @participants.where.not(responded_at: nil).order(responded_at: :desc).limit(5).each do |participant| %>
          <div class="mb-2">
            <strong><%= participant.user.full_name %></strong><br>
            <span class="badge bg-<%= participant.rsvp_status == 'yes' ? 'success' : 'secondary' %>">
              <%= participant.rsvp_status.humanize %>
            </span>
            <small class="text-muted">
              <%= time_ago_in_words(participant.responded_at) %> ago
            </small>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
EVENT_SHOW_EOF

# 4. Create Event form view
echo "Creating event form view..."
cat > app/views/admin/events/_form.html.erb << 'EVENT_FORM_EOF'
<div class="row justify-content-center">
  <div class="col-md-8">
    <div class="card">
      <div class="card-body">
        <%= form_with(model: [:admin, @event], local: true) do |form| %>
          <% if @event.errors.any? %>
            <div class="alert alert-danger">
              <h4><%= pluralize(@event.errors.count, "error") %> prohibited this event from being saved:</h4>
              <ul class="mb-0">
                <% @event.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div class="mb-3">
            <%= form.label :name, class: "form-label" %>
            <%= form.text_field :name, class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= form.label :description, class: "form-label" %>
            <%= form.text_area :description, class: "form-control", rows: 3 %>
          </div>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= form.label :venue_id, "Venue", class: "form-label" %>
              <%= form.select :venue_id, options_from_collection_for_select(@venues, :id, :name, @event.venue_id), 
                              { prompt: "Select a venue" }, { class: "form-select", required: true } %>
            </div>
            <div class="col-md-6 mb-3">
              <%= form.label :max_attendees, class: "form-label" %>
              <%= form.number_field :max_attendees, class: "form-control", required: true, min: 1 %>
            </div>
          </div>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= form.label :event_date, "Event Date", class: "form-label" %>
              <%= form.datetime_local_field :event_date, class: "form-control", required: true %>
            </div>
            <div class="col-md-6 mb-3">
              <%= form.label :rsvp_deadline, "RSVP Deadline", class: "form-label" %>
              <%= form.datetime_local_field :rsvp_deadline, class: "form-control", required: true %>
            </div>
          </div>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= form.label :start_time, class: "form-label" %>
              <%= form.time_field :start_time, class: "form-control" %>
            </div>
            <div class="col-md-6 mb-3">
              <%= form.label :end_time, class: "form-label" %>
              <%= form.time_field :end_time, class: "form-control" %>
            </div>
          </div>

          <div class="d-grid gap-2 d-md-flex justify-content-md-end">
            <%= link_to "Cancel", admin_events_path, class: "btn btn-outline-secondary me-md-2" %>
            <%= form.submit class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
EVENT_FORM_EOF

# 5. Create Event new and edit views
echo "Creating event new and edit views..."
cat > app/views/admin/events/new.html.erb << 'EVENT_NEW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>New Event</h2>
  <%= link_to "Back to Events", admin_events_path, class: "btn btn-outline-secondary" %>
</div>

<%= render 'form', event: @event %>
EVENT_NEW_EOF

cat > app/views/admin/events/edit.html.erb << 'EVENT_EDIT_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Edit Event: <%= @event.name %></h2>
  <div>
    <%= link_to "View Event", admin_event_path(@event), class: "btn btn-info me-2" %>
    <%= link_to "Back to Events", admin_events_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<%= render 'form', event: @event %>

<div class="mt-4 text-center">
  <%= link_to "Delete Event", admin_event_path(@event), method: :delete, 
              confirm: "Are you sure? This will also remove all participants.", 
              class: "btn btn-danger" %>
</div>
EVENT_EDIT_EOF

echo "✓ Events views created"

# 6. Create Venues views
echo "Creating venues views..."

cat > app/views/admin/venues/index.html.erb << 'VENUES_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Venues</h2>
  <div>
    <%= link_to "New Venue", new_admin_venue_path, class: "btn btn-success me-2" %>
    <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="card">
  <div class="card-body">
    <% if @venues.any? %>
      <div class="table-responsive">
        <table class="table table-striped">
          <thead>
            <tr>
              <th>Name</th>
              <th>Address</th>
              <th>Capacity</th>
              <th>Events</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @venues.each do |venue| %>
              <tr>
                <td>
                  <%= link_to venue.name, admin_venue_path(venue), class: "fw-bold text-decoration-none" %>
                </td>
                <td><%= truncate(venue.address, length: 50) %></td>
                <td><span class="badge bg-info"><%= venue.capacity %></span></td>
                <td>
                  <span class="badge bg-primary"><%= venue.events_count %></span>
                  <% if venue.upcoming_events.any? %>
                    <small class="text-success">(<%= venue.upcoming_events.count %> upcoming)</small>
                  <% end %>
                </td>
                <td>
                  <div class="btn-group btn-group-sm">
                    <%= link_to "View", admin_venue_path(venue), class: "btn btn-outline-primary" %>
                    <%= link_to "Edit", edit_admin_venue_path(venue), class: "btn btn-outline-secondary" %>
                    <% if venue.events.empty? %>
                      <%= link_to "Delete", admin_venue_path(venue), method: :delete, 
                                  confirm: "Are you sure?", class: "btn btn-outline-danger" %>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div class="text-center py-5">
        <h4 class="text-muted">No venues found</h4>
        <p class="text-muted">Create your first venue to get started.</p>
        <%= link_to "Create Venue", new_admin_venue_path, class: "btn btn-success" %>
      </div>
    <% end %>
  </div>
</div>
VENUES_INDEX_EOF

cat > app/views/admin/venues/show.html.erb << 'VENUE_SHOW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2><%= @venue.name %></h2>
  <div>
    <%= link_to "Edit Venue", edit_admin_venue_path(@venue), class: "btn btn-warning me-2" %>
    <%= link_to "Back to Venues", admin_venues_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>Venue Details</h5>
      </div>
      <div class="card-body">
        <div class="row">
          <div class="col-md-6">
            <p><strong>Name:</strong> <%= @venue.name %></p>
            <p><strong>Capacity:</strong> <%= @venue.capacity %> people</p>
          </div>
          <div class="col-md-6">
            <p><strong>Total Events:</strong> <%= @venue.events_count %></p>
            <p><strong>Upcoming Events:</strong> <%= @upcoming_events.count %></p>
          </div>
        </div>
        <div class="mt-3">
          <strong>Address:</strong>
          <p><%= simple_format(@venue.address) %></p>
        </div>
        <% if @venue.description.present? %>
          <div class="mt-3">
            <strong>Description:</strong>
            <p><%= simple_format(@venue.description) %></p>
          </div>
        <% end %>
        <% if @venue.contact_info.present? %>
          <div class="mt-3">
            <strong>Contact Information:</strong>
            <p><%= simple_format(@venue.contact_info) %></p>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Upcoming Events</h6>
      </div>
      <div class="card-body">
        <% if @upcoming_events.any? %>
          <% @upcoming_events.each do |event| %>
            <div class="mb-3 border-bottom pb-2">
              <%= link_to event.name, admin_event_path(event), class: "fw-bold text-decoration-none" %>
              <br>
              <small class="text-muted">
                <%= event.event_date&.strftime("%b %d, %Y") %>
              </small>
              <br>
              <span class="badge bg-primary"><%= event.attendees_count %> / <%= event.max_attendees %></span>
            </div>
          <% end %>
        <% else %>
          <p class="text-muted">No upcoming events</p>
        <% end %>
      </div>
    </div>
  </div>
</div>
VENUE_SHOW_EOF

cat > app/views/admin/venues/_form.html.erb << 'VENUE_FORM_EOF'
<div class="row justify-content-center">
  <div class="col-md-8">
    <div class="card">
      <div class="card-body">
        <%= form_with(model: [:admin, @venue], local: true) do |form| %>
          <% if @venue.errors.any? %>
            <div class="alert alert-danger">
              <h4><%= pluralize(@venue.errors.count, "error") %> prohibited this venue from being saved:</h4>
              <ul class="mb-0">
                <% @venue.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div class="mb-3">
            <%= form.label :name, class: "form-label" %>
            <%= form.text_field :name, class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= form.label :address, class: "form-label" %>
            <%= form.text_area :address, class: "form-control", rows: 3, required: true %>
          </div>

          <div class="mb-3">
            <%= form.label :capacity, class: "form-label" %>
            <%= form.number_field :capacity, class: "form-control", required: true, min: 1 %>
          </div>

          <div class="mb-3">
            <%= form.label :description, class: "form-label" %>
            <%= form.text_area :description, class: "form-control", rows: 3 %>
          </div>

          <div class="mb-3">
            <%= form.label :contact_info, "Contact Information", class: "form-label" %>
            <%= form.text_area :contact_info, class: "form-control", rows: 3 %>
          </div>

          <div class="d-grid gap-2 d-md-flex justify-content-md-end">
            <%= link_to "Cancel", admin_venues_path, class: "btn btn-outline-secondary me-md-2" %>
            <%= form.submit class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
VENUE_FORM_EOF

cat > app/views/admin/venues/new.html.erb << 'VENUE_NEW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>New Venue</h2>
  <%= link_to "Back to Venues", admin_venues_path, class: "btn btn-outline-secondary" %>
</div>

<%= render 'form', venue: @venue %>
VENUE_NEW_EOF

cat > app/views/admin/venues/edit.html.erb << 'VENUE_EDIT_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Edit Venue: <%= @venue.name %></h2>
  <div>
    <%= link_to "View Venue", admin_venue_path(@venue), class: "btn btn-info me-2" %>
    <%= link_to "Back to Venues", admin_venues_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<%= render 'form', venue: @venue %>

<div class="mt-4 text-center">
  <% if @venue.events.empty? %>
    <%= link_to "Delete Venue", admin_venue_path(@venue), method: :delete, 
                confirm: "Are you sure?", class: "btn btn-danger" %>
  <% else %>
    <p class="text-muted">Cannot delete venue with existing events.</p>
  <% end %>
</div>
VENUE_EDIT_EOF

echo "✓ Venues views created"

# 7. Create Event Participants views
echo "Creating event participants views..."

cat > app/views/admin/event_participants/index.html.erb << 'PARTICIPANTS_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Participants: <%= @event.name %></h2>
  <div>
    <%= link_to "View Event", admin_event_path(@event), class: "btn btn-info me-2" %>
    <%= link_to "Back to Events", admin_events_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>Current Participants (<%= @participants.count %>)</h5>
      </div>
      <div class="card-body">
        <% if @participants.any? %>
          <div class="table-responsive">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Company</th>
                  <th>Role</th>
                  <th>RSVP Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <% @participants.each do |participant| %>
                  <tr>
                    <td><%= participant.user.full_name %></td>
                    <td><%= participant.user.company %></td>
                    <td>
                      <%= form_with(model: [:admin, @event, participant], local: true, method: :patch) do |form| %>
                        <%= form.select :role, 
                            options_for_select([
                              ['Attendee', 'attendee'],
                              ['Vendor', 'vendor'], 
                              ['Organizer', 'organizer']
                            ], participant.role),
                            {}, 
                            { class: "form-select form-select-sm", onchange: "this.form.submit();" } %>
                      <% end %>
                    </td>
                    <td>
                      <span class="badge bg-<%= participant.rsvp_status == 'yes' ? 'success' : participant.rsvp_status == 'maybe' ? 'warning' : participant.rsvp_status == 'no' ? 'danger' : 'secondary' %>">
                        <%= participant.rsvp_status.humanize %>
                      </span>
                    </td>
                    <td>
                      <%= link_to "Remove", admin_event_event_participant_path(@event, participant), 
                                  method: :delete, confirm: "Remove this participant?", 
                                  class: "btn btn-outline-danger btn-sm" %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <p class="text-muted">No participants yet.</p>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h5>Add Participant</h5>
      </div>
      <div class="card-body">
        <%= form_with(model: [:admin, @event, EventParticipant.new], local: true) do |form| %>
          <div class="mb-3">
            <%= form.label :user_id, "User", class: "form-label" %>
            <%= form.select :user_id, 
                options_from_collection_for_select(@users, :id, :full_name), 
                { prompt: "Select a user" }, 
                { class: "form-select", required: true } %>
          </div>
          
          <div class="mb-3">
            <%= form.label :role, class: "form-label" %>
            <%= form.select :role, 
                options_for_select([
                  ['Attendee', 'attendee'],
                  ['Vendor', 'vendor'],
                  ['Organizer', 'organizer']
                ]), 
                {}, 
                { class: "form-select" } %>
          </div>
          
          <div class="mb-3">
            <%= form.label :notes, class: "form-label" %>
            <%= form.text_area :notes, class: "form-control", rows: 2 %>
          </div>
          
          <div class="d-grid">
            <%= form.submit "Add Participant", class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
    
    <div class="card mt-3">
      <div class="card-header">
        <h6>Quick Stats</h6>
      </div>
      <div class="card-body">
        <p><strong>Organizers:</strong> <%= @participants.organizer.count %></p>
        <p><strong>Vendors:</strong> <%= @participants.vendor.count %></p>
        <p><strong>Attendees:</strong> <%= @participants.attendee.count %></p>
        <hr>
        <p><strong>Confirmed:</strong> <%= @participants.yes.count %></p>
        <p><strong>Pending:</strong> <%= @participants.pending.count %></p>
      </div>
    </div>
  </div>
</div>
PARTICIPANTS_INDEX_EOF

echo "✓ Event participants views created"

# 8. Create Users views
echo "Creating users views..."

cat > app/views/admin/users/index.html.erb << 'USERS_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Users</h2>
  <div>
    <%= link_to "New User", new_admin_user_path, class: "btn btn-success me-2" %>
    <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="card">
  <div class="card-body">
    <% if @users.any? %>
      <div class="table-responsive">
        <table class="table table-striped">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Company</th>
              <th>Role</th>
              <th>Events</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @users.each do |user| %>
              <tr>
                <td>
                  <%= link_to user.full_name, admin_user_path(user), class: "fw-bold text-decoration-none" %>
                </td>
                <td><%= user.email %></td>
                <td><%= user.company %></td>
                <td>
                  <% if user.admin? %>
                    <span class="badge bg-danger">Admin</span>
                  <% else %>
                    <span class="badge bg-secondary">User</span>
                  <% end %>
                </td>
                <td>
                  <span class="badge bg-primary"><%= user.event_participants.count %></span>
                </td>
                <td>
                  <div class="btn-group btn-group-sm">
                    <%= link_to "View", admin_user_path(user), class: "btn btn-outline-primary" %>
                    <%= link_to "Edit", edit_admin_user_path(user), class: "btn btn-outline-secondary" %>
                    <% unless user == current_user %>
                      <%= link_to "Delete", admin_user_path(user), method: :delete, 
                                  confirm: "Are you sure?", class: "btn btn-outline-danger" %>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div class="text-center py-5">
        <h4 class="text-muted">No users found</h4>
        <p class="text-muted">Create your first user to get started.</p>
        <%= link_to "Create User", new_admin_user_path, class: "btn btn-success" %>
      </div>
    <% end %>
  </div>
</div>
USERS_INDEX_EOF

cat > app/views/admin/users/show.html.erb << 'USER_SHOW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2><%= @user.full_name %></h2>
  <div>
    <%= link_to "Edit User", edit_admin_user_path(@user), class: "btn btn-warning me-2" %>
    <%= link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>User Details</h5>
      </div>
      <div class="card-body">
        <div class="row">
          <div class="col-md-6">
            <p><strong>First Name:</strong> <%= @user.first_name %></p>
            <p><strong>Last Name:</strong> <%= @user.last_name %></p>
            <p><strong>Email:</strong> <%= @user.email %></p>
            <p><strong>Phone:</strong> <%= @user.phone %></p>
          </div>
          <div class="col-md-6">
            <p><strong>Company:</strong> <%= @user.company %></p>
            <p><strong>Role:</strong> 
              <% if @user.admin? %>
                <span class="badge bg-danger">Admin</span>
              <% else %>
                <span class="badge bg-secondary">User</span>
              <% end %>
            </p>
            <p><strong>Created:</strong> <%= @user.created_at.strftime("%B %d, %Y") %></p>
            <p><strong>Last Sign In:</strong> 
              <%= @user.last_sign_in_at&.strftime("%B %d, %Y") || "Never" %>
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Event Participation</h6>
      </div>
      <div class="card-body">
        <p><strong>Total Events:</strong> <%= @user.event_participants.count %></p>
        <p><strong>As Organizer:</strong> <%= @user.event_participants.organizer.count %></p>
        <p><strong>As Vendor:</strong> <%= @user.event_participants.vendor.count %></p>
        <p><strong>As Attendee:</strong> <%= @user.event_participants.attendee.count %></p>
      </div>
    </div>
  </div>
</div>

<% if @user.event_participants.any? %>
  <div class="card mt-4">
    <div class="card-header">
      <h5>Event History</h5>
    </div>
    <div class="card-body">
      <div class="table-responsive">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Event</th>
              <th>Date</th>
              <th>Role</th>
              <th>RSVP Status</th>
            </tr>
          </thead>
          <tbody>
            <% @user.event_participants.includes(:event).order('events.event_date DESC').each do |participant| %>
              <tr>
                <td>
                  <%= link_to participant.event.name, admin_event_path(participant.event), class: "text-decoration-none" %>
                </td>
                <td><%= participant.event.event_date&.strftime("%b %d, %Y") %></td>
                <td>
                  <span class="badge bg-<%= participant.organizer? ? 'success' : participant.vendor? ? 'warning' : 'secondary' %>">
                    <%= participant.role.humanize %>
                  </span>
                </td>
                <td>
                  <span class="badge bg-<%= participant.rsvp_status == 'yes' ? 'success' : participant.rsvp_status == 'maybe' ? 'warning' : participant.rsvp_status == 'no' ? 'danger' : 'secondary' %>">
                    <%= participant.rsvp_status.humanize %>
                  </span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
  </div>
<% end %>
USER_SHOW_EOF

cat > app/views/admin/users/_form.html.erb << 'USER_FORM_EOF'
<div class="row justify-content-center">
  <div class="col-md-8">
    <div class="card">
      <div class="card-body">
        <%= form_with(model: [:admin, @user], local: true) do |form| %>
          <% if @user.errors.any? %>
            <div class="alert alert-danger">
              <h4><%= pluralize(@user.errors.count, "error") %> prohibited this user from being saved:</h4>
              <ul class="mb-0">
                <% @user.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= form.label :first_name, class: "form-label" %>
              <%= form.text_field :first_name, class: "form-control", required: true %>
            </div>
            <div class="col-md-6 mb-3">
              <%= form.label :last_name, class: "form-label" %>
              <%= form.text_field :last_name, class: "form-control", required: true %>
            </div>
          </div>

          <div class="mb-3">
            <%= form.label :email, class: "form-label" %>
            <%= form.email_field :email, class: "form-control", required: true %>
          </div>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= form.label :company, class: "form-label" %>
              <%= form.text_field :company, class: "form-control" %>
            </div>
            <div class="col-md-6 mb-3">
              <%= form.label :phone, class: "form-label" %>
              <%= form.telephone_field :phone, class: "form-control" %>
            </div>
          </div>

          <% if @user.new_record? %>
            <div class="row">
              <div class="col-md-6 mb-3">
                <%= form.label :password, class: "form-label" %>
                <%= form.password_field :password, class: "form-control", required: true %>
              </div>
              <div class="col-md-6 mb-3">
                <%= form.label :password_confirmation, class: "form-label" %>
                <%= form.password_field :password_confirmation, class: "form-control", required: true %>
              </div>
            </div>
          <% end %>

          <div class="mb-3">
            <div class="form-check">
              <%= form.check_box :admin, class: "form-check-input" %>
              <%= form.label :admin, "Administrator", class: "form-check-label" %>
            </div>
          </div>

          <div class="d-grid gap-2 d-md-flex justify-content-md-end">
            <%= link_to "Cancel", admin_users_path, class: "btn btn-outline-secondary me-md-2" %>
            <%= form.submit class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
</div>
USER_FORM_EOF

cat > app/views/admin/users/new.html.erb << 'USER_NEW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>New User</h2>
  <%= link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary" %>
</div>

<%= render 'form', user: @user %>
USER_NEW_EOF

cat > app/views/admin/users/edit.html.erb << 'USER_EDIT_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Edit User: <%= @user.full_name %></h2>
  <div>
    <%= link_to "View User", admin_user_path(@user), class: "btn btn-info me-2" %>
    <%= link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<%= render 'form', user: @user %>

<div class="mt-4 text-center">
  <% unless @user == current_user %>
    <%= link_to "Delete User", admin_user_path(@user), method: :delete, 
                confirm: "Are you sure? This will remove the user from all events.", 
                class: "btn btn-danger" %>
  <% end %>
</div>
USER_EDIT_EOF

echo "✓ Users views created"

# 9. Update main navigation with improved styling
echo "Updating main layout navigation..."
cat > app/views/layouts/application.html.erb << 'LAYOUT_EOF'
<!DOCTYPE html>
<html>
  <head>
    <title>PTC Windchill Event</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  </head>

  <body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
      <div class="container">
        <%= link_to "PTC Windchill Event", root_path, class: "navbar-brand" %>
        
        <div class="navbar-nav ms-auto d-flex align-items-center">
          <% if user_signed_in? %>
            <span class="navbar-text me-3">Hello, <%= current_user.full_name %></span>
            <% if current_user.admin? %>
              <div class="d-flex align-items-center gap-2 me-3">
                <%= link_to admin_root_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" do %>
                  📊 Dashboard
                <% end %>
                <%= link_to admin_events_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" do %>
                  📅 Events
                <% end %>
                <%= link_to admin_venues_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" do %>
                  🏢 Venues
                <% end %>
                <%= link_to admin_users_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" do %>
                  👥 Users
                <% end %>
              </div>
            <% end %>
            <%= link_to "Sign Out", destroy_user_session_path, data: { "turbo-method": :delete }, class: "nav-link" %>
          <% else %>
            <%= link_to "Sign In", new_user_session_path, class: "nav-link" %>
          <% end %>
        </div>
      </div>
    </nav>

    <main class="container mt-4">
      <% flash.each do |type, message| %>
        <div class="alert alert-<%= type == 'notice' ? 'success' : 'danger' %> alert-dismissible fade show">
          <%= message %>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      <% end %>

      <%= yield %>
    </main>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
LAYOUT_EOF

# 10. Update user dashboard for multi-event support
echo "Updating user dashboard..."
cat > app/views/dashboard/index.html.erb << 'DASHBOARD_EOF'
<div class="row">
  <div class="col-md-8">
    <% if @current_event %>
      <div class="card mb-4">
        <div class="card-header d-flex justify-content-between">
          <h4><%= @current_event.name %></h4>
          <% if @my_role == 'vendor' %>
            <span class="badge bg-warning">Vendor</span>
          <% elsif @my_role == 'organizer' %>
            <span class="badge bg-success">Organizer</span>
          <% end %>
        </div>
        <div class="card-body">
          <p><strong>Date:</strong> <%= @current_event.event_date&.strftime("%A, %B %d, %Y") %></p>
          <p><strong>Time:</strong> <%= @current_event.start_time&.strftime("%I:%M %p") %> - <%= @current_event.end_time&.strftime("%I:%M %p") %></p>
          <p><strong>Location:</strong> <%= @current_event.venue&.full_address %></p>
          <p><strong>RSVP Deadline:</strong> <%= @current_event.rsvp_deadline&.strftime("%B %d, %Y at %I:%M %p") %></p>
          <% if @current_event.description.present? %>
            <p><strong>Description:</strong> <%= simple_format(@current_event.description) %></p>
          <% end %>
        </div>
      </div>

      <div class="card mb-4">
        <div class="card-header">
          <h5>Your RSVP Status: 
            <span class="badge bg-<%= @user_rsvp_status == 'yes' ? 'success' : @user_rsvp_status == 'maybe' ? 'warning' : @user_rsvp_status == 'no' ? 'danger' : 'secondary' %>">
              <%= @user_rsvp_status.humanize %>
            </span>
          </h5>
        </div>
        <div class="card-body">
          <% unless @deadline_passed %>
            <div class="btn-group" role="group">
              <%= link_to "Yes", rsvp_path('yes', event_id: @current_event.id), data: { "turbo-method": :patch }, 
                          class: "btn #{'btn-success' if @user_rsvp_status == 'yes'} #{'btn-outline-success' if @user_rsvp_status != 'yes'}" %>
              <%= link_to "Maybe", rsvp_path('maybe', event_id: @current_event.id), data: { "turbo-method": :patch }, 
                          class: "btn #{'btn-warning' if @user_rsvp_status == 'maybe'} #{'btn-outline-warning' if @user_rsvp_status != 'maybe'}" %>
              <%= link_to "No", rsvp_path('no', event_id: @current_event.id), data: { "turbo-method": :patch }, 
                          class: "btn #{'btn-danger' if @user_rsvp_status == 'no'} #{'btn-outline-danger' if @user_rsvp_status != 'no'}" %>
            </div>
            <div class="mt-2">
              <small class="text-muted">
                <% days_left = ((@current_event.rsvp_deadline - Time.current) / 1.day).ceil %>
                <%= pluralize(days_left, 'day') %> left to RSVP
              </small>
            </div>
          <% else %>
            <p class="text-muted">RSVP deadline has passed.</p>
          <% end %>
        </div>
      </div>
    <% end %>

    <% if @events.count > 1 %>
      <div class="card">
        <div class="card-header">
          <h5>All Upcoming Events</h5>
        </div>
        <div class="card-body">
          <% @events.each do |event| %>
            <div class="border-bottom py-2 <%= 'bg-light' if event == @current_event %>">
              <div class="d-flex justify-content-between">
                <div>
                  <strong><%= event.name %></strong><br>
                  <small class="text-muted">
                    <%= event.event_date&.strftime("%b %d, %Y") %> at <%= event.venue&.name %>
                  </small>
                  <% participant = current_user.event_participants.find_by(event: event) %>
                  <% if participant %>
                    <br>
                    <span class="badge bg-secondary"><%= participant.rsvp_status.humanize %></span>
                    <% if participant.vendor? %>
                      <span class="badge bg-warning">Vendor</span>
                    <% elsif participant.organizer? %>
                      <span class="badge bg-success">Organizer</span>
                    <% end %>
                  <% end %>
                </div>
                <div>
                  <span class="badge bg-primary"><%= event.attendees_count %> / <%= event.max_attendees %></span>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
  
  <div class="col-md-4">
    <div class="card mb-3">
      <div class="card-header">
        <h5>Your Profile</h5>
      </div>
      <div class="card-body">
        <p><strong>Name:</strong> <%= current_user.full_name %></p>
        <p><strong>Email:</strong> <%= current_user.email %></p>
        <p><strong>Company:</strong> <%= current_user.company %></p>
        <p><strong>Phone:</strong> <%= current_user.phone %></p>
      </div>
    </div>

    <% if @my_events.any? %>
      <div class="card">
        <div class="card-header">
          <h6>My Events</h6>
        </div>
        <div class="card-body">
          <% @my_events.each do |event| %>
            <% participant = current_user.event_participants.find_by(event: event) %>
            <div class="mb-2">
              <strong><%= event.name %></strong><br>
              <small class="text-muted"><%= event.event_date&.strftime("%b %d") %></small>
              <% if participant %>
                <br>
                <span class="badge bg-<%= participant.rsvp_status == 'yes' ? 'success' : 'secondary' %>">
                  <%= participant.rsvp_status.humanize %>
                </span>
                <% if participant.vendor? %>
                  <span class="badge bg-warning">Vendor</span>
                <% elsif participant.organizer? %>
                  <span class="badge bg-success">Organizer</span>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
DASHBOARD_EOF

# Run any pending migrations
echo "Running migrations..."
rails db:migrate

# Return to original directory
cd "$ORIGINAL_DIR"

echo ""
echo "SUCCESS! Fixed admin views for vendor management and multi-event CRUD created!"
echo ""
echo "New Admin Features Available:"
echo "- Complete event management with participant roles"
echo "- Full venue CRUD operations" 
echo "- User management interface"
echo "- Vendor assignment per event"
echo "- Enhanced admin dashboard with statistics"
echo "- Participant management interface"
echo "- Improved badge-style navigation with emojis"
echo ""
echo "Test the new features at: http://localhost:3000/admin"