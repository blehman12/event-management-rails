#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Setting up bulk user management system..."

cd "$APP_NAME"

# Add CSV processing gem
if ! grep -q "gem 'csv'" Gemfile; then
  echo "gem 'csv'" >> Gemfile
  bundle install
fi

# Generate Bulk Users Controller
rails generate controller Admin::BulkUsers index create

cat > app/controllers/admin/bulk_users_controller.rb << 'BULK_CONTROLLER_EOF'
class Admin::BulkUsersController < Admin::BaseController
  def index
    @recent_imports = User.where('created_at > ?', 7.days.ago).order(created_at: :desc).limit(20)
  end

  def create
    if params[:user_file].present?
      process_csv_upload
    elsif params[:bulk_invite]
      process_bulk_invite
    elsif params[:bulk_role_update]
      process_bulk_role_update
    end
    
    redirect_to admin_bulk_users_path
  end

  private

  def process_csv_upload
    require 'csv'
    
    begin
      csv_content = params[:user_file].read.force_encoding('UTF-8')
      imported_count = 0
      error_count = 0
      errors = []

      CSV.parse(csv_content, headers: true, header_converters: :symbol) do |row|
        user_params = {
          first_name: row[:first_name],
          last_name: row[:last_name],
          email: row[:email],
          phone: row[:phone],
          company: row[:company],
          password: row[:password] || 'TempPass123!',
          text_capable: row[:text_capable]&.downcase == 'true',
          invited_at: Time.current
        }

        user = User.new(user_params)
        
        if user.save
          imported_count += 1
          
          # Add to event if specified
          if row[:event_id].present?
            event = Event.find_by(id: row[:event_id])
            if event
              role = row[:role]&.downcase || 'attendee'
              event.add_participant(user, role: role)
            end
          end
        else
          error_count += 1
          errors << "Row #{CSV.parse(csv_content, headers: true).find_index(row) + 2}: #{user.errors.full_messages.join(', ')}"
        end
      end

      if imported_count > 0
        flash[:notice] = "Successfully imported #{imported_count} users."
      end
      
      if error_count > 0
        flash[:alert] = "#{error_count} users failed to import. Errors: #{errors.join('; ')}"
      end

    rescue CSV::MalformedCSVError => e
      flash[:alert] = "CSV parsing error: #{e.message}"
    rescue => e
      flash[:alert] = "Import error: #{e.message}"
    end
  end

  def process_bulk_invite
    event = Event.find(params[:event_id])
    user_ids = params[:user_ids].reject(&:blank?)
    role = params[:role] || 'attendee'
    
    added_count = 0
    
    user_ids.each do |user_id|
      user = User.find(user_id)
      unless event.users.include?(user)
        event.add_participant(user, role: role)
        added_count += 1
      end
    end
    
    flash[:notice] = "Added #{added_count} participants to #{event.name}"
  end

  def process_bulk_role_update
    event = Event.find(params[:event_id])
    role_updates = params[:role_updates] || {}
    
    updated_count = 0
    
    role_updates.each do |participant_id, new_role|
      participant = event.event_participants.find(participant_id)
      if participant.update(role: new_role)
        updated_count += 1
      end
    end
    
    flash[:notice] = "Updated #{updated_count} participant roles"
  end
end
BULK_CONTROLLER_EOF

# Create bulk users views
mkdir -p app/views/admin/bulk_users

cat > app/views/admin/bulk_users/index.html.erb << 'BULK_USERS_VIEW_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Bulk User Management</h2>
  <%= link_to "Back to Dashboard", admin_root_path, class: "btn btn-outline-secondary" %>
</div>

<div class="row">
  <div class="col-md-6">
    <!-- CSV Import -->
    <div class="card mb-4">
      <div class="card-header">
        <h5>Import Users from CSV</h5>
      </div>
      <div class="card-body">
        <%= form_with url: admin_bulk_users_path, multipart: true, local: true do |form| %>
          <div class="mb-3">
            <%= form.label :user_file, "CSV File", class: "form-label" %>
            <%= form.file_field :user_file, accept: ".csv", class: "form-control", required: true %>
            <div class="form-text">
              Expected columns: first_name, last_name, email, phone, company, password (optional), text_capable (true/false), event_id (optional), role (optional)
            </div>
          </div>
          <div class="d-grid">
            <%= form.submit "Import Users", class: "btn btn-success" %>
          </div>
        <% end %>
        
        <hr>
        
        <h6>Sample CSV Format:</h6>
        <pre class="bg-light p-2 small">first_name,last_name,email,phone,company,text_capable,event_id,role
John,Doe,john@example.com,503-555-0123,Acme Corp,true,1,attendee
Jane,Smith,jane@example.com,503-555-0124,Tech Inc,false,,vendor</pre>
      </div>
    </div>
    
    <!-- Bulk Event Assignment -->
    <div class="card">
      <div class="card-header">
        <h5>Bulk Add to Event</h5>
      </div>
      <div class="card-body">
        <%= form_with url: admin_bulk_users_path, local: true do |form| %>
          <%= form.hidden_field :bulk_invite, value: true %>
          
          <div class="mb-3">
            <%= form.label :event_id, "Event", class: "form-label" %>
            <%= form.select :event_id, options_from_collection_for_select(Event.upcoming.order(:event_date), :id, :name), 
                            { prompt: "Select an event" }, { class: "form-select", required: true } %>
          </div>
          
          <div class="mb-3">
            <%= form.label :role, "Role", class: "form-label" %>
            <%= form.select :role, [['Attendee', 'attendee'], ['Vendor', 'vendor'], ['Organizer', 'organizer']], 
                            {}, { class: "form-select" } %>
          </div>
          
          <div class="mb-3">
            <%= form.label :user_ids, "Users", class: "form-label" %>
            <%= form.select :user_ids, options_from_collection_for_select(User.order(:last_name, :first_name), :id, :full_name), 
                            {}, { class: "form-select", multiple: true, size: 8, required: true } %>
            <div class="form-text">Hold Ctrl/Cmd to select multiple users</div>
          </div>
          
          <div class="d-grid">
            <%= form.submit "Add to Event", class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-6">
    <!-- Recent Imports -->
    <div class="card mb-4">
      <div class="card-header">
        <h5>Recent Imports (Last 7 Days)</h5>
      </div>
      <div class="card-body">
        <% if @recent_imports.any? %>
          <div class="table-responsive">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Company</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                <% @recent_imports.each do |user| %>
                  <tr>
                    <td><%= user.full_name %></td>
                    <td><%= user.email %></td>
                    <td><%= truncate(user.company, length: 20) %></td>
                    <td><%= time_ago_in_words(user.created_at) %> ago</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <p class="text-muted">No recent imports</p>
        <% end %>
      </div>
    </div>
    
    <!-- Quick Actions -->
    <div class="card">
      <div class="card-header">
        <h5>Quick Actions</h5>
      </div>
      <div class="card-body">
        <div class="d-grid gap-2">
          <%= link_to "Download Sample CSV", "#", class: "btn btn-outline-info", 
                      onclick: "downloadSampleCSV(); return false;" %>
          <%= link_to "View All Users", admin_users_path, class: "btn btn-outline-primary" %>
          <%= link_to "Manage Events", admin_events_path, class: "btn btn-outline-success" %>
        </div>
      </div>
    </div>
  </div>
</div>

<script>
function downloadSampleCSV() {
  const csvContent = `first_name,last_name,email,phone,company,password,text_capable,event_id,role
John,Doe,john.doe@example.com,503-555-0123,Acme Corporation,TempPass123!,true,1,attendee
Jane,Smith,jane.smith@techcorp.com,503-555-0124,Tech Corporation,TempPass123!,false,1,vendor
Bob,Johnson,bob.johnson@consulting.com,503-555-0125,PLM Consulting,TempPass123!,true,,organizer`;
  
  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'sample_users.csv';
  a.click();
  window.URL.revokeObjectURL(url);
}
</script>
BULK_USERS_VIEW_EOF

# Update routes for bulk users
sed -i '/resources :users/a\    resources :bulk_users, only: [:index, :create]' config/routes.rb

rails db:migrate

echo "Bulk user management setup completed!"
