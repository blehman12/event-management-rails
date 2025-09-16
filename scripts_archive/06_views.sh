#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 6: Creating views"

cd "$APP_NAME"

# Application layout
mkdir -p app/views/layouts
cat > app/views/layouts/application.html.erb << 'EOF'
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
        <div class="navbar-nav ms-auto">
          <% if user_signed_in? %>
            <span class="navbar-text me-3">Hello, <%= current_user.full_name %></span>
            <% if current_user.admin? %>
              <%= link_to "Admin", admin_root_path, class: "nav-link" %>
            <% end %>
            <%= link_to "Sign Out", destroy_user_session_path, data: { "turbo-method": :delete }, class: "nav-link" %>
          <% else %>
            <%= link_to "Sign In", new_user_session_path, class: "nav-link" %>
          <% end %>
        </div>
      </div>
    </nav>
    <% if notice || alert %>
      <div class="container mt-3">
        <% if notice %>
          <div class="alert alert-success alert-dismissible">
            <%= notice %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
          </div>
        <% end %>
        <% if alert %>
          <div class="alert alert-danger alert-dismissible">
            <%= alert %>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
          </div>
        <% end %>
      </div>
    <% end %>
    <main class="container mt-4">
      <%= yield %>
    </main>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
EOF

# FIXED: Dashboard view matching monolithic version
mkdir -p app/views/dashboard
cat > app/views/dashboard/index.html.erb << 'EOF'
<div class="row">
  <div class="col-md-8">
    <h2>PTC Windchill Community Event</h2>
    
    <% if @event %>
      <div class="card mb-4">
        <div class="card-header">
          <h4><%= @event.name %></h4>
        </div>
        <div class="card-body">
          <p><strong>Date:</strong> <%= @event.event_date&.strftime("%A, %B %d, %Y") || "September 20th, 2024" %></p>
          <p><strong>Location:</strong> <%= @event.venue&.full_address || "Portland, OR" %></p>
          <p><strong>Description:</strong> <%= @event.description || "Join the PTC Windchill community!" %></p>
        </div>
      </div>

      <div class="card mb-4">
        <div class="card-header">
          <h5>Your RSVP Status: <span class="badge bg-secondary"><%= @user_rsvp_status.humanize %></span></h5>
        </div>
        <div class="card-body">
          <% unless @deadline_passed %>
            <div class="btn-group" role="group">
              <%= link_to "Yes", rsvp_path('yes'), data: { "turbo-method": :patch }, class: "btn btn-success" %>
              <%= link_to "Maybe", rsvp_path('maybe'), data: { "turbo-method": :patch }, class: "btn btn-warning" %>
              <%= link_to "No", rsvp_path('no'), data: { "turbo-method": :patch }, class: "btn btn-outline-danger" %>
            </div>
          <% else %>
            <p class="text-muted">RSVP deadline has passed.</p>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="alert alert-info">
        <h4>Event details coming soon!</h4>
      </div>
    <% end %>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h5>Your Profile</h5>
      </div>
      <div class="card-body">
        <p><strong>Name:</strong> <%= current_user.full_name %></p>
        <p><strong>Email:</strong> <%= current_user.email %></p>
        <p><strong>Company:</strong> <%= current_user.company %></p>
      </div>
    </div>
  </div>
</div>
EOF

# Admin views (same as original but fixed layout)
mkdir -p app/views/admin/dashboard
cat > app/views/admin/dashboard/index.html.erb << 'EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Admin Dashboard</h2>
  <%= link_to "Back to Main Site", root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="row mb-4">
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Total Invited</h5>
        <h2 class="text-primary"><%= @total_invited %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Yes RSVPs</h5>
        <h2 class="text-success"><%= @rsvp_counts[:yes] %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Maybe RSVPs</h5>
        <h2 class="text-warning"><%= @rsvp_counts[:maybe] %></h2>
      </div>
    </div>
  </div>
  <div class="col-md-3">
    <div class="card text-center">
      <div class="card-body">
        <h5>Pending</h5>
        <h2 class="text-secondary"><%= @rsvp_counts[:pending] %></h2>
      </div>
    </div>
  </div>
</div>

<div class="row">
  <div class="col-md-12">
    <div class="card">
      <div class="card-header">
        <h5>Quick Actions</h5>
      </div>
      <div class="card-body">
        <%= link_to "Manage Users", admin_users_path, class: "btn btn-primary me-2" %>
        <%= link_to "Manage Events", admin_events_path, class: "btn btn-primary me-2" %>
        <%= link_to "Manage Venues", admin_venues_path, class: "btn btn-primary" %>
      </div>
    </div>
  </div>
</div>
EOF

mkdir -p app/views/admin/users
cat > app/views/admin/users/index.html.erb << 'EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Users</h2>
  <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="card">
  <div class="card-body">
    <table class="table table-striped">
      <thead>
        <tr>
          <th>Name</th>
          <th>Email</th>
          <th>Company</th>
          <th>Role</th>
          <th>RSVP Status</th>
        </tr>
      </thead>
      <tbody>
        <% @users.each do |user| %>
          <tr>
            <td><%= user.full_name %></td>
            <td><%= user.email %></td>
            <td><%= user.company %></td>
            <td><span class="badge bg-<%= user.admin? ? 'danger' : 'secondary' %>"><%= user.role.humanize %></span></td>
            <td><span class="badge bg-secondary"><%= user.rsvp_status.humanize %></span></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
EOF

mkdir -p app/views/admin/events
cat > app/views/admin/events/index.html.erb << 'EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Events</h2>
  <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="card">
  <div class="card-body">
    <% if @events.any? %>
      <table class="table table-striped">
        <thead>
          <tr>
            <th>Name</th>
            <th>Date</th>
            <th>Venue</th>
            <th>Max Attendees</th>
          </tr>
        </thead>
        <tbody>
          <% @events.each do |event| %>
            <tr>
              <td><%= event.name %></td>
              <td><%= event.event_date&.strftime("%B %d, %Y") %></td>
              <td><%= event.venue&.name %></td>
              <td><%= event.max_attendees %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p>No events found.</p>
    <% end %>
  </div>
</div>
EOF

mkdir -p app/views/admin/venues
cat > app/views/admin/venues/index.html.erb << 'EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Manage Venues</h2>
  <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="card">
  <div class="card-body">
    <% if @venues.any? %>
      <table class="table table-striped">
        <thead>
          <tr>
            <th>Name</th>
            <th>Address</th>
            <th>Capacity</th>
          </tr>
        </thead>
        <tbody>
          <% @venues.each do |venue| %>
            <tr>
              <td><%= venue.name %></td>
              <td><%= venue.address %></td>
              <td><%= venue.capacity %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p>No venues found.</p>
    <% end %>
  </div>
</div>
EOF

echo "✓ Views created"
