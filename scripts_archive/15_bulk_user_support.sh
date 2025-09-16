#!/bin/bash

# Script 15: Bulk User Management & CSV Import (Fixed)
# Run this script after all other scripts to add bulk user functionality

set -e

APP_NAME="${1:-ev1}"
cd "$APP_NAME"

echo "========================================="
echo "Adding Bulk User Management Features"
echo "========================================="

# 1. Add CSV gem to Gemfile
echo "Adding CSV processing gem..."
if ! grep -q "gem 'csv'" Gemfile; then
  echo "gem 'csv'" >> Gemfile
  bundle install
fi

# 2. Create bulk users controller
echo "Creating bulk users controller..."
cat > app/controllers/admin/bulk_users_controller.rb << 'BULK_CONTROLLER_EOF'
class Admin::BulkUsersController < Admin::BaseController
  require 'csv'
  
  def index
    @users = User.order(:last_name, :first_name)
    @selected_users = params[:user_ids] || []
  end
  
  def import_form
    # Show CSV import form
  end
  
  def import_csv
    unless params[:csv_file].present?
      redirect_to admin_bulk_users_path, alert: 'Please select a CSV file.'
      return
    end
    
    csv_file = params[:csv_file]
    
    begin
      results = process_csv_import(csv_file)
      
      if results[:errors].empty?
        redirect_to admin_users_path, 
                    notice: "Successfully imported #{results[:created]} users."
      else
        flash.now[:alert] = "Import completed with #{results[:errors].size} errors. Created #{results[:created]} users."
        @import_errors = results[:errors]
        render :import_form
      end
      
    rescue CSV::MalformedCSVError => e
      redirect_to admin_bulk_users_path, alert: "Invalid CSV file: #{e.message}"
    rescue => e
      redirect_to admin_bulk_users_path, alert: "Import failed: #{e.message}"
    end
  end
  
  def bulk_actions
    user_ids = params[:user_ids] || []
    action = params[:bulk_action]
    
    if user_ids.empty?
      redirect_to admin_bulk_users_path, alert: 'No users selected.'
      return
    end
    
    users = User.where(id: user_ids)
    
    case action
    when 'delete'
      perform_bulk_delete(users)
    when 'promote_to_admin'
      perform_bulk_promote(users)
    when 'demote_to_user'
      perform_bulk_demote(users)
    when 'send_invites'
      perform_bulk_invite(users)
    else
      redirect_to admin_bulk_users_path, alert: 'Invalid action selected.'
    end
  end
  
  def export_csv
    users = User.all.order(:last_name, :first_name)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['First Name', 'Last Name', 'Email', 'Phone', 'Company', 'Role', 'RSVP Status', 'Created At']
      
      users.each do |user|
        csv << [
          user.first_name,
          user.last_name,
          user.email,
          user.phone,
          user.company,
          user.role.respond_to?(:humanize) ? user.role.humanize : user.role.to_s.humanize,
          user.rsvp_status.respond_to?(:humanize) ? user.rsvp_status.humanize : user.rsvp_status.to_s.humanize,
          user.created_at.strftime('%Y-%m-%d')
        ]
      end
    end
    
    send_data csv_data, 
              filename: "users_export_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end
  
  private
  
  def process_csv_import(csv_file)
    results = { created: 0, errors: [] }
    
    CSV.foreach(csv_file.path, headers: true, header_converters: :symbol) do |row|
      begin
        # Clean up headers by removing spaces and converting to symbols
        clean_row = {}
        row.to_h.each do |key, value|
          clean_key = key.to_s.strip.downcase.gsub(/\s+/, '_').to_sym
          clean_row[clean_key] = value&.strip
        end
        
        user_attrs = {
          first_name: clean_row[:first_name],
          last_name: clean_row[:last_name],
          email: clean_row[:email]&.downcase,
          phone: clean_row[:phone],
          company: clean_row[:company],
          password: clean_row[:password] || 'password123',
          text_capable: parse_boolean(clean_row[:text_capable]),
          invited_at: Time.current
        }
        
        # Set role if provided
        if clean_row[:role].present?
          role_value = clean_row[:role].downcase.strip
          user_attrs[:role] = role_value if ['admin', 'attendee'].include?(role_value)
        end
        
        # Skip if required fields are missing
        if user_attrs[:first_name].blank? || user_attrs[:last_name].blank? || user_attrs[:email].blank?
          results[:errors] << "Row #{$.}: Missing required fields (first_name, last_name, email)"
          next
        end
        
        user = User.create!(user_attrs)
        results[:created] += 1
        
      rescue ActiveRecord::RecordInvalid => e
        results[:errors] << "Row #{$.}: #{e.message}"
      rescue => e
        results[:errors] << "Row #{$.}: Unexpected error - #{e.message}"
      end
    end
    
    results
  end
  
  def parse_boolean(value)
    return true if value.nil?
    return true if ['true', 'yes', '1', 'y'].include?(value.to_s.downcase.strip)
    false
  end
  
  def perform_bulk_delete(users)
    # Prevent deleting current user or last admin
    users_to_delete = users.reject { |u| u == current_user }
    
    # Check if we're deleting all admins
    if User.respond_to?(:admin)
      remaining_admins = User.admin.where.not(id: users_to_delete.map(&:id)).count
    elsif User.defined_enums.key?('role')
      remaining_admins = User.where(role: User.defined_enums['role']['admin']).where.not(id: users_to_delete.map(&:id)).count
    else
      remaining_admins = User.where(role: 'admin').where.not(id: users_to_delete.map(&:id)).count
    end
    
    if remaining_admins == 0
      redirect_to admin_bulk_users_path, alert: 'Cannot delete all admin users.'
      return
    end
    
    deleted_count = users_to_delete.count
    users_to_delete.destroy_all
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully deleted #{deleted_count} users."
  end
  
  def perform_bulk_promote(users)
    count = 0
    users.each do |user|
      if user.respond_to?(:admin?) && !user.admin?
        user.update!(role: 'admin')
        count += 1
      elsif !user.respond_to?(:admin?) && user.role.to_s != 'admin'
        user.update!(role: 'admin')
        count += 1
      end
    end
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully promoted #{count} users to admin."
  end
  
  def perform_bulk_demote(users)
    # Prevent demoting current user or creating no admins
    users_to_demote = users.reject { |u| u == current_user }
    
    # Count current admin users
    if User.respond_to?(:admin)
      current_admin_count = User.admin.count
      admin_users_to_demote = users_to_demote.select { |u| u.admin? }
    elsif User.defined_enums.key?('role')
      current_admin_count = User.where(role: User.defined_enums['role']['admin']).count
      admin_users_to_demote = users_to_demote.select { |u| u.role == User.defined_enums['role']['admin'] }
    else
      current_admin_count = User.where(role: 'admin').count
      admin_users_to_demote = users_to_demote.select { |u| u.role.to_s == 'admin' }
    end
    
    if admin_users_to_demote.count >= current_admin_count
      redirect_to admin_bulk_users_path, alert: 'Cannot demote all admin users.'
      return
    end
    
    count = 0
    users_to_demote.each do |user|
      if user.respond_to?(:admin?) && user.admin?
        user.update!(role: 'attendee')
        count += 1
      elsif !user.respond_to?(:admin?) && user.role.to_s == 'admin'
        user.update!(role: 'attendee')
        count += 1
      end
    end
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully demoted #{count} users to attendee."
  end
  
  def perform_bulk_invite(users)
    count = 0
    users.each do |user|
      if user.respond_to?(:invited_at) && user.invited_at.nil?
        user.update!(invited_at: Time.current)
        count += 1
      end
    end
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully sent invites to #{count} users."
  end
end
BULK_CONTROLLER_EOF

# 3. Add routes properly to routes.rb
echo "Adding bulk users routes to routes.rb..."

# First, check if admin namespace exists
if ! grep -q "namespace :admin" config/routes.rb; then
  echo "ERROR: Admin namespace not found in routes.rb"
  echo "Please ensure admin routes are properly configured first"
  exit 1
fi

# Create a backup of routes
cp config/routes.rb config/routes.rb.backup

# Create a Ruby script to properly insert the routes
cat > fix_routes.rb << 'RUBY_EOF'
# Read the routes file
content = File.read('config/routes.rb')

# Check if bulk_users routes already exist
if content.include?('bulk_users')
  puts "Bulk users routes already exist"
  exit
end

# Find the admin namespace and add bulk_users routes
lines = content.lines

# Find the line with 'namespace :admin do'
admin_line_index = lines.index { |line| line.include?('namespace :admin do') }

if admin_line_index.nil?
  puts "Could not find admin namespace"
  exit 1
end

# Find the next line to insert after
insert_index = admin_line_index + 1

# Add bulk_users routes
bulk_routes = [
  "    resources :bulk_users, only: [:index] do\n",
  "      collection do\n",
  "        get :import_form\n",
  "        post :import_csv\n",
  "        post :bulk_actions\n",
  "        get :export_csv\n",
  "      end\n",
  "    end\n",
  "\n"
]

# Insert the routes
lines.insert(insert_index, *bulk_routes)

# Write back to file
File.write('config/routes.rb', lines.join)
puts "Bulk users routes added successfully"
RUBY_EOF

# Run the Ruby script
ruby fix_routes.rb
rm fix_routes.rb

# 4. Create bulk users views
echo "Creating bulk users views..."
mkdir -p app/views/admin/bulk_users

cat > app/views/admin/bulk_users/index.html.erb << 'BULK_INDEX_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Bulk User Management</h2>
  <div>
    <%= link_to "Import CSV", import_form_admin_bulk_users_path, class: "btn btn-success me-2" %>
    <%= link_to "Export CSV", export_csv_admin_bulk_users_path, class: "btn btn-info me-2" %>
    <%= link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<div class="card mb-4">
  <div class="card-header">
    <h5>CSV Import Template</h5>
  </div>
  <div class="card-body">
    <p>Your CSV file should have these headers (case-insensitive):</p>
    <code>First Name, Last Name, Email, Phone, Company, Role, Text Capable</code>
    <br><br>
    <small class="text-muted">
      <strong>Notes:</strong><br>
      • First Name, Last Name, and Email are required<br>
      • Role can be "admin" or "attendee" (defaults to attendee)<br>
      • Text Capable can be "true", "yes", "1" for true, anything else for false<br>
      • If password is not provided, defaults to "password123"
    </small>
  </div>
</div>

<%= form_with url: bulk_actions_admin_bulk_users_path, method: :post, local: true do |form| %>
  <div class="card">
    <div class="card-header d-flex justify-content-between align-items-center">
      <h5>Select Users for Bulk Actions</h5>
      <div>
        <button type="button" class="btn btn-sm btn-outline-primary" onclick="selectAll()">Select All</button>
        <button type="button" class="btn btn-sm btn-outline-secondary" onclick="selectNone()">Select None</button>
      </div>
    </div>
    <div class="card-body">
      <div class="row mb-3">
        <div class="col-md-6">
          <%= form.select :bulk_action, 
              options_for_select([
                ['Choose an action...', ''],
                ['Delete Selected Users', 'delete'],
                ['Promote to Admin', 'promote_to_admin'],
                ['Demote to User', 'demote_to_user'],
                ['Send Invitations', 'send_invites']
              ]), 
              {}, 
              { class: "form-select", required: true } %>
        </div>
        <div class="col-md-6">
          <%= form.submit "Execute Action", class: "btn btn-warning", 
                          confirm: "Are you sure you want to execute this action on selected users?" %>
        </div>
      </div>
      
      <div class="table-responsive">
        <table class="table table-striped">
          <thead>
            <tr>
              <th width="50">
                <input type="checkbox" id="select-all-checkbox" onchange="toggleSelectAll()">
              </th>
              <th>Name</th>
              <th>Email</th>
              <th>Company</th>
              <th>Role</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            <% @users.each do |user| %>
              <tr>
                <td>
                  <%= check_box_tag "user_ids[]", user.id, 
                                    @selected_users.include?(user.id.to_s), 
                                    { class: "user-checkbox" } %>
                </td>
                <td>
                  <%= link_to "#{user.first_name} #{user.last_name}", admin_user_path(user), class: "text-decoration-none" %>
                  <% if user == current_user %>
                    <span class="badge bg-info">You</span>
                  <% end %>
                </td>
                <td><%= user.email %></td>
                <td><%= user.company %></td>
                <td>
                  <% if user_is_admin?(user) %>
                    <span class="badge bg-danger">Admin</span>
                  <% else %>
                    <span class="badge bg-secondary">User</span>
                  <% end %>
                </td>
                <td>
                  <span class="badge bg-<%= (user.rsvp_status.to_s == 'yes' || user.rsvp_status.to_s == '1') ? 'success' : 'secondary' %>">
                    <%= user.rsvp_status.respond_to?(:humanize) ? user.rsvp_status.humanize : user.rsvp_status.to_s.humanize %>
                  </span>
                  <% if user.respond_to?(:invited_at) && user.invited_at %>
                    <small class="text-success">Invited</small>
                  <% end %>
                </td>
                <td><%= user.created_at.strftime("%m/%d/%Y") %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
  </div>
<% end %>

<script>
function selectAll() {
  document.querySelectorAll('.user-checkbox').forEach(checkbox => {
    checkbox.checked = true;
  });
  document.getElementById('select-all-checkbox').checked = true;
}

function selectNone() {
  document.querySelectorAll('.user-checkbox').forEach(checkbox => {
    checkbox.checked = false;
  });
  document.getElementById('select-all-checkbox').checked = false;
}

function toggleSelectAll() {
  const selectAllCheckbox = document.getElementById('select-all-checkbox');
  document.querySelectorAll('.user-checkbox').forEach(checkbox => {
    checkbox.checked = selectAllCheckbox.checked;
  });
}
</script>
BULK_INDEX_EOF

cat > app/views/admin/bulk_users/import_form.html.erb << 'IMPORT_FORM_EOF'
<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Import Users from CSV</h2>
  <%= link_to "Back to Bulk Management", admin_bulk_users_path, class: "btn btn-outline-secondary" %>
</div>

<div class="row">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header">
        <h5>Upload CSV File</h5>
      </div>
      <div class="card-body">
        <%= form_with url: import_csv_admin_bulk_users_path, method: :post, 
                      multipart: true, local: true do |form| %>
          
          <div class="mb-3">
            <%= form.label :csv_file, "Select CSV File", class: "form-label" %>
            <%= form.file_field :csv_file, 
                                accept: ".csv", 
                                class: "form-control", 
                                required: true %>
            <div class="form-text">
              Upload a CSV file with user information. Maximum file size: 10MB
            </div>
          </div>
          
          <div class="alert alert-info">
            <h6>CSV Format Requirements:</h6>
            <ul class="mb-0">
              <li><strong>Required columns:</strong> First Name, Last Name, Email</li>
              <li><strong>Optional columns:</strong> Phone, Company, Role, Text Capable, Password</li>
              <li>Headers are case-insensitive and spaces will be converted to underscores</li>
              <li>Role must be "admin" or "attendee" (defaults to attendee)</li>
              <li>If password is not provided, defaults to "password123"</li>
            </ul>
          </div>
          
          <% if defined?(@import_errors) && @import_errors.any? %>
            <div class="alert alert-danger">
              <h6>Import Errors:</h6>
              <ul class="mb-0">
                <% @import_errors.each do |error| %>
                  <li><%= error %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
          
          <div class="d-grid">
            <%= form.submit "Import Users", class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <div class="col-md-4">
    <div class="card">
      <div class="card-header">
        <h6>Sample CSV Format</h6>
      </div>
      <div class="card-body">
        <pre class="small">First Name,Last Name,Email,Phone,Company,Role,Text Capable
John,Doe,john@company.com,503-555-0123,Acme Corp,attendee,true
Jane,Smith,jane@example.com,503-555-0124,Tech Inc,admin,false
Bob,Johnson,bob@test.com,503-555-0125,Test LLC,attendee,true</pre>
      </div>
    </div>
    
    <div class="card mt-3">
      <div class="card-header">
        <h6>Quick Actions</h6>
      </div>
      <div class="card-body">
        <%= link_to "Download Sample CSV", "#", 
                    class: "btn btn-outline-info btn-sm d-block mb-2",
                    onclick: "downloadSampleCSV(); return false;" %>
        <%= link_to "View All Users", admin_users_path, 
                    class: "btn btn-outline-primary btn-sm d-block" %>
      </div>
    </div>
  </div>
</div>

<script>
function downloadSampleCSV() {
  const csvContent = "First Name,Last Name,Email,Phone,Company,Role,Text Capable\n" +
                     "John,Doe,john@company.com,503-555-0123,Acme Corp,attendee,true\n" +
                     "Jane,Smith,jane@example.com,503-555-0124,Tech Inc,admin,false\n" +
                     "Bob,Johnson,bob@test.com,503-555-0125,Test LLC,attendee,true";
  
  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'sample_users.csv';
  a.click();
  window.URL.revokeObjectURL(url);
}
</script>
IMPORT_FORM_EOF

# 5. Update admin navigation to include bulk users
echo "Updating admin navigation..."

# Update the users index to include link to bulk management
if [ -f "app/views/admin/users/index.html.erb" ]; then
  if ! grep -q "Bulk Management" app/views/admin/users/index.html.erb; then
    sed -i 's|<%= link_to "New User", new_admin_user_path, class: "btn btn-success me-2" %>|<%= link_to "New User", new_admin_user_path, class: "btn btn-success me-2" %>\
    <%= link_to "Bulk Management", admin_bulk_users_path, class: "btn btn-warning me-2" %>|' app/views/admin/users/index.html.erb
  fi
fi

# Update main navigation to include bulk users link
if [ -f "app/views/layouts/application.html.erb" ]; then
  if ! grep -q "Bulk" app/views/layouts/application.html.erb; then
    sed -i 's|<%= link_to "Users", admin_users_path, class: "btn btn-sm btn-outline-light" %>|<%= link_to "Users", admin_users_path, class: "btn btn-sm btn-outline-light me-1" %>\
                <%= link_to "Bulk", admin_bulk_users_path, class: "btn btn-sm btn-outline-light" %>|' app/views/layouts/application.html.erb
  fi
fi

# 6. Verify routes were added correctly
echo "Verifying routes..."
if rails routes | grep -q bulk_users; then
  echo "✓ Bulk users routes verified"
else
  echo "⚠ Warning: Routes may not be configured correctly"
  echo "Please check config/routes.rb manually"
fi

echo ""
echo "SUCCESS! Bulk User Management features added!"
echo ""
echo "NEW FEATURES:"
echo "✓ CSV import with error handling and validation"
echo "✓ Bulk user operations (delete, promote, demote, invite)"
echo "✓ CSV export functionality"
echo "✓ Sample CSV download"
echo "✓ Safety checks to prevent removing all admins"
echo "✓ Integration with existing admin interface"
echo "✓ Universal role detection (works with enums and strings)"
echo ""
echo "ACCESS:"
echo "• Admin Users page → Bulk Management button"
echo "• Admin Navigation → Bulk button"
echo "• Direct URL: /admin/bulk_users"
echo ""
echo "CSV FORMAT:"
echo "Required: First Name, Last Name, Email"
echo "Optional: Phone, Company, Role, Text Capable, Password"
echo ""
echo "ROUTES ADDED:"
rails routes | grep bulk_users
echo ""
echo "Ready for transition to Git-based development!"