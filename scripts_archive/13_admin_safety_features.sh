#!/bin/bash

# PTC Windchill Event App - Admin Safety Features
# Run this script from your Rails app root directory

# Store the original directory
ORIGINAL_DIR=$(pwd)

APP_NAME="${1:-ptc_windchill_event}"
cd "$APP_NAME"

set -e

echo "========================================="
echo "Adding Admin Safety Features"
echo "========================================="

# 1. Add JavaScript for admin role change confirmation
echo "Adding admin role change confirmation JavaScript..."
mkdir -p app/assets/javascripts

cat > app/assets/javascripts/admin_safety.js << 'ADMIN_JS_EOF'
// Admin Safety Features
document.addEventListener('DOMContentLoaded', function() {
  // Find role select elements in admin forms
  const roleSelects = document.querySelectorAll('select[name*="[role]"]');
  
  roleSelects.forEach(function(select) {
    // Store the original role value
    const originalRole = select.value;
    
    select.addEventListener('change', function() {
      const newRole = this.value;
      
      // Check if we're demoting an admin
      if (originalRole === 'admin' && newRole !== 'admin') {
        const confirmed = confirm(
          '⚠️ WARNING: You are removing admin privileges!\n\n' +
          'This user will lose access to:\n' +
          '• Admin dashboard\n' +
          '• User management\n' +
          '• Event management\n' +
          '• Venue management\n\n' +
          'Are you sure you want to continue?'
        );
        
        if (!confirmed) {
          // Reset to original value if they cancel
          this.value = originalRole;
          return false;
        }
      }
      
      // Check if we're promoting someone to admin
      if (originalRole !== 'admin' && newRole === 'admin') {
        const confirmed = confirm(
          '🔑 You are granting admin privileges to this user.\n\n' +
          'They will gain access to:\n' +
          '• Admin dashboard\n' +
          '• User management\n' +
          '• Event management\n' +
          '• Venue management\n\n' +
          'Are you sure you want to continue?'
        );
        
        if (!confirmed) {
          // Reset to original value if they cancel
          this.value = originalRole;
          return false;
        }
      }
    });
  });
  
  // Prevent self-demotion
  const currentUserEmail = document.body.dataset.currentUserEmail;
  const editUserEmail = document.body.dataset.editUserEmail;
  
  if (currentUserEmail && editUserEmail && currentUserEmail === editUserEmail) {
    roleSelects.forEach(function(select) {
      select.addEventListener('change', function() {
        if (this.value !== 'admin') {
          alert('⛔ You cannot remove your own admin privileges!\n\nAsk another admin to change your role if needed.');
          this.value = 'admin';
          return false;
        }
      });
    });
  }
});
ADMIN_JS_EOF

# 2. Update the admin users edit form to include the JavaScript and user data
echo "Updating admin user edit form..."
cat > app/views/admin/users/edit.html.erb << 'USER_EDIT_EOF'
<% content_for :head do %>
  <%= javascript_include_tag 'admin_safety', defer: true %>
<% end %>

<div class="d-flex justify-content-between align-items-center mb-4">
  <h2>Edit User: <%= @user.full_name %></h2>
  <div>
    <%= link_to "View User", admin_user_path(@user), class: "btn btn-info me-2" %>
    <%= link_to "Back to Users", admin_users_path, class: "btn btn-outline-secondary" %>
  </div>
</div>

<!-- Add user data for JavaScript -->
<% content_for :body_data do %>
  data-current-user-email="<%= current_user.email %>" 
  data-edit-user-email="<%= @user.email %>"
<% end %>

<%= render 'form', user: @user %>

<div class="mt-4 text-center">
  <% unless @user == current_user %>
    <%= link_to "Delete User", admin_user_path(@user), method: :delete, 
                confirm: "Are you sure? This will remove the user from all events.", 
                class: "btn btn-danger" %>
  <% else %>
    <p class="text-muted">You cannot delete your own account.</p>
  <% end %>
</div>
USER_EDIT_EOF

# 3. Update the user form to highlight role changes
echo "Updating user form with role highlighting..."
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

          <!-- Highlighted Role Section -->
          <div class="mb-3">
            <div class="card border-warning">
              <div class="card-header bg-warning text-dark">
                <h6 class="mb-0">🔐 User Role & Permissions</h6>
              </div>
              <div class="card-body">
                <%= form.label :role, "User Role", class: "form-label fw-bold" %>
                <%= form.select :role, 
                    options_for_select([
                      ['Attendee - Can RSVP to events', 'attendee'],
                      ['Admin - Full system access', 'admin']
                    ], @user.role),
                    {}, 
                    { class: "form-select form-select-lg", 
                      style: "border: 2px solid #ffc107;" } %>
                <div class="form-text">
                  <strong>Attendee:</strong> Can view and RSVP to events<br>
                  <strong>Admin:</strong> Can manage users, events, venues, and all system settings
                </div>
                
                <% if @user.persisted? && @user == current_user %>
                  <div class="alert alert-info mt-2 mb-0">
                    <small>💡 This is your own account. You cannot remove your own admin privileges.</small>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="mb-3">
            <div class="form-check">
              <%= form.check_box :text_capable, class: "form-check-input" %>
              <%= form.label :text_capable, "Can receive text messages", class: "form-check-label" %>
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

# 4. Update application layout to support body data attributes
echo "Updating application layout for JavaScript data..."
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
    
    <%= yield :head %>
  </head>

  <body <%= yield :body_data %>>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
      <div class="container">
        <%= link_to "PTC Windchill Event", root_path, class: "navbar-brand" %>
        
        <div class="navbar-nav ms-auto d-flex align-items-center">
          <% if user_signed_in? %>
            <span class="navbar-text me-3">Hello, <%= current_user.full_name %></span>
            <% if current_user.role == 'admin' %>
              <span class="me-3">
                <%= link_to "Dashboard", admin_root_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Events", admin_events_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Venues", admin_venues_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Users", admin_users_path, class: "btn btn-sm btn-outline-light" %>
              </span>
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

# 5. Add server-side validation to User model for additional safety
echo "Adding server-side admin role validation..."

# First, let's properly edit the User model by inserting validations before the final 'end'
# We need to be careful to add it inside the class definition

# Create a temporary script to properly insert the validations
cat > temp_user_model_fix.rb << 'USER_MODEL_SCRIPT'
# Read the current User model
content = File.read('app/models/user.rb')

# Find the last 'end' statement and insert our validations before it
lines = content.lines
last_end_index = lines.rindex { |line| line.strip == 'end' }

if last_end_index
  # Insert our validation code before the last 'end'
  validation_code = [
    "\n",
    "  # Admin safety validations\n",
    "  validate :cannot_demote_last_admin\n",
    "  validate :cannot_self_demote, on: :update\n",
    "\n",
    "  def editing_self=(value)\n",
    "    @editing_self = value\n",
    "  end\n",
    "\n",
    "  private\n",
    "\n",
    "  def cannot_demote_last_admin\n",
    "    if role_changed? && role_was == 'admin' && role != 'admin'\n",
    "      remaining_admins = User.where(role: 'admin').where.not(id: id).count\n",
    "      if remaining_admins == 0\n",
    "        errors.add(:role, 'Cannot remove the last admin user')\n",
    "      end\n",
    "    end\n",
    "  end\n",
    "\n",
    "  def cannot_self_demote\n",
    "    if defined?(@editing_self) && @editing_self && role_changed? && role_was == 'admin' && role != 'admin'\n",
    "      errors.add(:role, 'You cannot remove your own admin privileges')\n",
    "    end\n",
    "  end\n",
    "\n"
  ]
  
  # Insert the validation code
  lines.insert(last_end_index, *validation_code)
  
  # Write back to the file
  File.write('app/models/user.rb', lines.join)
  puts "User model validations added successfully"
else
  puts "Could not find proper insertion point in User model"
end
USER_MODEL_SCRIPT

# Run the Ruby script to properly insert the validations
ruby temp_user_model_fix.rb

# Clean up
rm temp_user_model_fix.rb

# 6. Update the admin users controller to prevent self-demotion
echo "Updating admin users controller with safety checks..."
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
    # Set flag for self-editing validation
    @user.editing_self = (@user == current_user)
    
    user_update_params = user_params
    
    # Prevent self-demotion at controller level too
    if @user == current_user && user_update_params[:role] != 'admin'
      redirect_to edit_admin_user_path(@user), 
                  alert: 'You cannot remove your own admin privileges.' and return
    end
    
    # Remove password fields if they're blank
    if user_update_params[:password].blank?
      user_update_params.delete(:password)
      user_update_params.delete(:password_confirmation)
    end
    
    if @user.update(user_update_params)
      if @user == current_user && @user.role != 'admin'
        # This shouldn't happen due to validation, but just in case
        sign_out current_user
        redirect_to root_path, alert: 'Admin privileges removed. Please contact another admin.'
      else
        redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
      end
    else
      render :edit
    end
  end
  
  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: 'You cannot delete your own account.'
    elsif @user.role == 'admin' && User.where(role: 'admin').count == 1
      redirect_to admin_user_path(@user), alert: 'Cannot delete the last admin user.'
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

# 7. Add the JavaScript file to the asset pipeline
echo "Configuring asset pipeline..."
if [ -f "app/assets/config/manifest.js" ]; then
  echo "//= link admin_safety.js" >> app/assets/config/manifest.js
fi

# Return to original directory
cd "$ORIGINAL_DIR"

echo ""
echo "SUCCESS! Admin safety features have been added!"
echo ""
echo "New Safety Features:"
echo "- JavaScript confirmation when changing admin roles"
echo "- Prevention of self-demotion (cannot remove own admin privileges)"
echo "- Prevention of removing the last admin user"
echo "- Visual highlighting of role selection in forms"
echo "- Server-side validations as backup"
echo ""
echo "Features include:"
echo "✓ Confirmation dialogs for role changes"
echo "✓ Self-demotion prevention"
echo "✓ Last admin protection"
echo "✓ Visual role selection highlighting"
echo "✓ Server-side safety validations"
echo ""
echo "Test the safety features by trying to change admin roles at:"
echo "http://localhost:3000/admin/users"