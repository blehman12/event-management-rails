cd ev1

# Create the dashboard view with proper syntax
cat > app/views/dashboard/index.html.erb << 'EOF'
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
          <p><strong>Location:</strong> <%= @current_event.venue&.address %></p>
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
              <%= button_to "Yes", rsvp_path('yes'), params: { event_id: @current_event.id }, method: :patch, class: "btn #{'btn-success' if @user_rsvp_status == 'yes'} #{'btn-outline-success' if @user_rsvp_status != 'yes'}" %>
              <%= button_to "Maybe", rsvp_path('maybe'), params: { event_id: @current_event.id }, method: :patch, class: "btn #{'btn-warning' if @user_rsvp_status == 'maybe'} #{'btn-outline-warning' if @user_rsvp_status != 'maybe'}" %>
              <%= button_to "No", rsvp_path('no'), params: { event_id: @current_event.id }, method: :patch, class: "btn #{'btn-danger' if @user_rsvp_status == 'no'} #{'btn-outline-danger' if @user_rsvp_status != 'no'}" %>
            </div>
          <% else %>
            <p class="text-muted">RSVP deadline has passed.</p>
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
        <p><strong>Name:</strong> <%= current_user.first_name %> <%= current_user.last_name %></p>
        <p><strong>Email:</strong> <%= current_user.email %></p>
        <p><strong>Company:</strong> <%= current_user.company %></p>
        <p><strong>Phone:</strong> <%= current_user.phone %></p>
      </div>
    </div>
  </div>
</div>
EOF