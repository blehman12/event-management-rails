#!/bin/bash

# PTC Windchill Event App - Environment Detection & Setup (Complete Regeneration)
# Run this script to detect model structure, configure environment, and fix common issues

set -e

APP_NAME="${1:-ev1}"
cd "$APP_NAME"

echo "========================================="
echo "Complete Environment Detection & Setup"
echo "========================================="

# 1. Create comprehensive detection script
echo "Creating model detection script..."
mkdir -p lib

cat > lib/model_detector.rb << 'DETECTOR_EOF'
#!/usr/bin/env ruby

# Model Structure Detection Script
require_relative '../config/environment'

puts "\n" + "="*60
puts "ENVIRONMENT DETECTION REPORT"
puts "="*60

# Rails Version
puts "\nRAILS CONFIGURATION:"
puts "  Rails Version: #{Rails.version}"
puts "  Ruby Version: #{RUBY_VERSION}"
puts "  Environment: #{Rails.env}"

# User Model Detection
puts "\nUSER MODEL ANALYSIS:"
begin
  user_columns = User.column_names
  puts "  Available Fields: #{user_columns.join(', ')}"
  
  # Check for enums
  if User.respond_to?(:defined_enums)
    enums = User.defined_enums
    puts "  Enums Defined: #{enums.keys.join(', ')}" if enums.any?
    enums.each do |field, values|
      puts "    #{field}: #{values}"
    end
  else
    puts "  No enums detected"
  end
  
  # Check field types
  role_col = User.columns.find { |c| c.name == 'role' }
  puts "  Role Field Type: #{role_col&.type || 'NOT FOUND'}"
  
  # Check Devise modules
  devise_modules = User.devise_modules rescue []
  puts "  Devise Modules: #{devise_modules.join(', ')}"
  
  # Test admin detection
  admin_count = begin
    if User.respond_to?(:admin)
      User.admin.count
    elsif User.defined_enums.key?('role')
      User.where(role: User.defined_enums['role']['admin']).count
    else
      User.where(role: 'admin').count
    end
  rescue
    0
  end
  puts "  Admin Users Count: #{admin_count}"
  
rescue => e
  puts "  ERROR: #{e.message}"
end

# EventParticipant Model Detection
puts "\nEVENT_PARTICIPANT MODEL ANALYSIS:"
begin
  if defined?(EventParticipant)
    ep_columns = EventParticipant.column_names
    puts "  Available Fields: #{ep_columns.join(', ')}"
    
    # Check for enums
    if EventParticipant.respond_to?(:defined_enums)
      enums = EventParticipant.defined_enums
      puts "  Enums Defined: #{enums.keys.join(', ')}" if enums.any?
      enums.each do |field, values|
        puts "    #{field}: #{values}"
      end
    end
  else
    puts "  EventParticipant model not found"
  end
rescue => e
  puts "  ERROR: #{e.message}"
end

# Event Model Detection
puts "\nEVENT MODEL ANALYSIS:"
begin
  if defined?(Event)
    event_columns = Event.column_names
    puts "  Available Fields: #{event_columns.join(', ')}"
  else
    puts "  Event model not found"
  end
rescue => e
  puts "  ERROR: #{e.message}"
end

# Routes Analysis
puts "\nROUTES ANALYSIS:"
begin
  routes_output = `rails routes 2>/dev/null`
  has_rsvp_route = routes_output.include?('rsvp_path')
  has_admin_routes = routes_output.include?('admin_root')
  has_dashboard_route = routes_output.include?('dashboard#index')
  
  puts "  RSVP Routes: #{has_rsvp_route ? 'FOUND' : 'MISSING'}"
  puts "  Admin Routes: #{has_admin_routes ? 'FOUND' : 'MISSING'}"
  puts "  Dashboard Route: #{has_dashboard_route ? 'FOUND' : 'MISSING'}"
rescue => e
  puts "  ERROR analyzing routes: #{e.message}"
end

# Asset Pipeline Detection
puts "\nASSET PIPELINE ANALYSIS:"
importmap_exists = File.exist?('config/importmap.rb')
puts "  Importmap Config: #{importmap_exists ? 'EXISTS' : 'MISSING'}"

manifest_exists = File.exist?('app/assets/config/manifest.js')
puts "  Asset Manifest: #{manifest_exists ? 'EXISTS' : 'MISSING'}"

js_dir_exists = Dir.exist?('app/javascript')
puts "  JavaScript Directory: #{js_dir_exists ? 'EXISTS' : 'MISSING'}"

# Development Config Analysis
puts "\nDEVELOPMENT CONFIG ANALYSIS:"
dev_config = File.read('config/environments/development.rb') rescue "FILE NOT FOUND"
has_digest_false = dev_config.include?('assets.digest = false')
has_debug_true = dev_config.include?('assets.debug = true')
puts "  Asset Digest Disabled: #{has_digest_false ? 'YES' : 'NO'}"
puts "  Asset Debug Enabled: #{has_debug_true ? 'YES' : 'NO'}"

# Controller Analysis
puts "\nCONTROLLER ANALYSIS:"
admin_controllers = Dir.glob('app/controllers/admin/*.rb').map { |f| File.basename(f, '.rb') }
puts "  Admin Controllers: #{admin_controllers.join(', ')}"

puts "\n" + "="*60
puts "DETECTION COMPLETE"
puts "="*60
DETECTOR_EOF

# 2. Run detection and capture output
echo "Running environment detection..."
ruby lib/model_detector.rb

# 3. Configure development environment for better asset handling
echo ""
echo "Configuring development environment..."

# Only add asset configuration if not already present
if ! grep -q "assets.digest = false" config/environments/development.rb; then
  # Create backup
  cp config/environments/development.rb config/environments/development.rb.backup
  
  # Add asset configuration after the Rails.application.configure line
  sed -i '/Rails.application.configure do/a\
\
  # Asset configuration for development - prevent caching issues\
  config.assets.digest = false\
  config.assets.debug = true\
  config.assets.compile = true\
  config.assets.check_precompiled_asset = false' config/environments/development.rb
  
  echo "✓ Added asset caching configuration to development.rb"
else
  echo "✓ Asset configuration already present"
fi

# 4. Set up proper JavaScript structure for Rails 7
echo "Setting up Rails 7 JavaScript structure..."

# Ensure app/javascript directory exists
mkdir -p app/javascript

# Update importmap.rb if needed
if [ ! -f "config/importmap.rb" ] || ! grep -q "stimulus" config/importmap.rb; then
  echo "Updating importmap configuration..."
  cat > config/importmap.rb << 'IMPORTMAP_EOF'
# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
IMPORTMAP_EOF
  echo "✓ Importmap configuration updated"
fi

# 5. Create universal authorization helper
echo "Creating universal authorization helper..."
mkdir -p app/helpers

cat > app/helpers/admin_helper.rb << 'ADMIN_HELPER_EOF'
module AdminHelper
  def user_is_admin?(user)
    return false unless user
    
    # Handle both string and enum-based role fields
    if user.respond_to?(:admin?)
      user.admin?
    elsif user.respond_to?(:role)
      case user.role
      when String
        user.role == 'admin'
      when Integer
        # Handle enum where admin = 1 (common Rails pattern)
        user.role == 1 || (user.respond_to?(:admin?) && user.admin?)
      else
        false
      end
    else
      false
    end
  end
  
  def role_display_name(user)
    return 'Unknown' unless user&.role
    
    if user.respond_to?(:admin?) && user.admin?
      'Admin'
    elsif user.role.respond_to?(:humanize)
      user.role.humanize
    else
      user.role.to_s.humanize
    end
  end
end
ADMIN_HELPER_EOF

# Include the helper in ApplicationHelper
echo "Including AdminHelper in ApplicationHelper..."
if [ -f "app/helpers/application_helper.rb" ]; then
  if ! grep -q "include AdminHelper" app/helpers/application_helper.rb; then
    # Add include to existing file
    sed -i '1a\  include AdminHelper' app/helpers/application_helper.rb
  fi
else
  # Create new application helper
  cat > app/helpers/application_helper.rb << 'APP_HELPER_EOF'
module ApplicationHelper
  include AdminHelper
end
APP_HELPER_EOF
fi

echo "✓ AdminHelper created and included"

# 6. Create universal layout that works with different configurations
echo "Creating universal admin-aware layout..."
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
            <span class="navbar-text me-3">
              Hello, <%= current_user.respond_to?(:full_name) ? current_user.full_name : "#{current_user.first_name} #{current_user.last_name}" %>
              <small class="text-muted">(<%= role_display_name(current_user) %>)</small>
            </span>
            <% if user_is_admin?(current_user) %>
              <span class="me-3">
                <%= link_to "Dashboard", admin_root_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Events", admin_events_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Venues", admin_venues_path, class: "btn btn-sm btn-outline-light me-1" %>
                <%= link_to "Users", admin_users_path, class: "btn btn-sm btn-outline-light" %>
              </span>
            <% end %>
            <%= button_to "Sign Out", destroy_user_session_path, method: :delete, 
                          class: "btn btn-link nav-link p-0 border-0", 
                          style: "color: rgba(255,255,255,.75); background: none;",
                          form: { style: "display: inline;" } %>
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

echo "✓ Universal layout created with admin detection"

# 7. Update admin base controller to use universal helper
echo "Updating admin base controller..."
mkdir -p app/controllers/admin

cat > app/controllers/admin/base_controller.rb << 'BASE_CONTROLLER_EOF'
class Admin::BaseController < ApplicationController
  include AdminHelper
  
  before_action :ensure_admin
  
  private
  
  def ensure_admin
    unless user_is_admin?(current_user)
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end
end
BASE_CONTROLLER_EOF

echo "✓ Admin base controller updated"

# 8. Fix RSVP routes and functionality
echo "Fixing RSVP functionality..."

# Ensure RSVP route exists in routes.rb
if ! grep -q "rsvp" config/routes.rb; then
  echo "Adding RSVP route..."
  sed -i '/root.*dashboard#index/a\  patch "rsvp/:status", to: "rsvp#update", as: :rsvp' config/routes.rb
fi

# Create/update RSVP controller
cat > app/controllers/rsvp_controller.rb << 'RSVP_CONTROLLER_EOF'
class RsvpController < ApplicationController
  before_action :authenticate_user!
  
  def update
    event = Event.find(params[:event_id]) if params[:event_id]
    event ||= Event.upcoming.first || Event.first
    
    if event.nil?
      redirect_to root_path, alert: "No event found"
      return
    end
    
    # Find or create participant record
    participant = current_user.event_participants.find_by(event: event)
    
    if participant
      # Update existing participant
      participant.update!(
        rsvp_status: params[:status],
        responded_at: Time.current
      )
      redirect_to root_path, notice: "RSVP updated to #{params[:status].humanize}"
    else
      # Handle legacy single-event RSVP system
      if current_user.respond_to?(:rsvp_status=)
        current_user.update!(rsvp_status: params[:status])
        current_user.update!(registered_at: Time.current) if current_user.registered_at.nil?
        redirect_to root_path, notice: "RSVP updated to #{params[:status].humanize}"
      else
        redirect_to root_path, alert: "Could not update RSVP"
      end
    end
  end
end
RSVP_CONTROLLER_EOF

echo "✓ RSVP controller updated"

# 9. Create dashboard view with proper RSVP buttons
echo "Creating dashboard view with universal RSVP support..."
mkdir -p app/views/dashboard

cat > app/views/dashboard/index.html.erb << 'DASHBOARD_EOF'
<div class="row">
  <div class="col-md-8">
    <% if defined?(@current_event) && @current_event %>
      <div class="card mb-4">
        <div class="card-header d-flex justify-content-between">
          <h4><%= @current_event.name %></h4>
          <% if defined?(@my_role) && @my_role == 'vendor' %>
            <span class="badge bg-warning">Vendor</span>
          <% elsif defined?(@my_role) && @my_role == 'organizer' %>
            <span class="badge bg-success">Organizer</span>
          <% end %>
        </div>
        <div class="card-body">
          <p><strong>Date:</strong> <%= @current_event.event_date&.strftime("%A, %B %d, %Y") %></p>
          <% if @current_event.respond_to?(:start_time) && @current_event.start_time %>
            <p><strong>Time:</strong> <%= @current_event.start_time.strftime("%I:%M %p") %> - <%= @current_event.end_time&.strftime("%I:%M %p") %></p>
          <% end %>
          <% if @current_event.venue %>
            <p><strong>Location:</strong> <%= @current_event.venue.respond_to?(:full_address) ? @current_event.venue.full_address : @current_event.venue.address %></p>
          <% end %>
          <% if @current_event.rsvp_deadline %>
            <p><strong>RSVP Deadline:</strong> <%= @current_event.rsvp_deadline.strftime("%B %d, %Y at %I:%M %p") %></p>
          <% end %>
          <% if @current_event.description.present? %>
            <p><strong>Description:</strong> <%= simple_format(@current_event.description) %></p>
          <% end %>
        </div>
      </div>

      <div class="card mb-4">
        <div class="card-header">
          <h5>Your RSVP Status: 
            <% 
              status_class = case @user_rsvp_status.to_s
                           when 'yes', '1' then 'success'
                           when 'maybe', '3' then 'warning' 
                           when 'no', '2' then 'danger'
                           else 'secondary'
                           end
            %>
            <span class="badge bg-<%= status_class %>">
              <%= @user_rsvp_status.respond_to?(:humanize) ? @user_rsvp_status.humanize : @user_rsvp_status.to_s.humanize %>
            </span>
          </h5>
        </div>
        <div class="card-body">
          <% unless defined?(@deadline_passed) && @deadline_passed %>
            <div class="btn-group" role="group">
              <%= button_to "Yes", rsvp_path('yes'), 
                    params: { event_id: @current_event.id }, 
                    method: :patch,
                    class: "btn #{(@user_rsvp_status.to_s == 'yes' || @user_rsvp_status.to_s == '1') ? 'btn-success' : 'btn-outline-success'}" %>
              <%= button_to "Maybe", rsvp_path('maybe'), 
                    params: { event_id: @current_event.id }, 
                    method: :patch,
                    class: "btn #{(@user_rsvp_status.to_s == 'maybe' || @user_rsvp_status.to_s == '3') ? 'btn-warning' : 'btn-outline-warning'}" %>
              <%= button_to "No", rsvp_path('no'), 
                    params: { event_id: @current_event.id }, 
                    method: :patch,
                    class: "btn #{(@user_rsvp_status.to_s == 'no' || @user_rsvp_status.to_s == '2') ? 'btn-danger' : 'btn-outline-danger'}" %>
            </div>
            <div class="mt-2">
              <small class="text-muted">
                <% if @current_event.rsvp_deadline && @current_event.rsvp_deadline > Time.current %>
                  <% days_left = ((@current_event.rsvp_deadline - Time.current) / 1.day).ceil %>
                  <%= pluralize(days_left, 'day') %> left to RSVP
                <% end %>
              </small>
            </div>
          <% else %>
            <p class="text-muted">RSVP deadline has passed.</p>
          <% end %>
        </div>
      </div>
    <% elsif defined?(@event) && @event %>
      <!-- Legacy single event display -->
      <div class="card mb-4">
        <div class="card-header">
          <h4><%= @event.name %></h4>
        </div>
        <div class="card-body">
          <p><strong>Date:</strong> <%= @event.event_date&.strftime("%A, %B %d, %Y") || "September 20th, 2024" %></p>
          <% if @event.venue %>
            <p><strong>Location:</strong> <%= @event.venue.respond_to?(:full_address) ? @event.venue.full_address : @event.venue.address %></p>
          <% end %>
          <p><strong>Description:</strong> <%= @event.description || "Join the PTC Windchill community!" %></p>
        </div>
      </div>

      <div class="card mb-4">
        <div class="card-header">
          <h5>Your RSVP Status: 
            <span class="badge bg-secondary"><%= @user_rsvp_status.respond_to?(:humanize) ? @user_rsvp_status.humanize : @user_rsvp_status.to_s.humanize %></span>
          </h5>
        </div>
        <div class="card-body">
          <% unless defined?(@deadline_passed) && @deadline_passed %>
            <div class="btn-group" role="group">
              <%= button_to "Yes", rsvp_path('yes'), method: :patch, class: "btn btn-success" %>
              <%= button_to "Maybe", rsvp_path('maybe'), method: :patch, class: "btn btn-warning" %>
              <%= button_to "No", rsvp_path('no'), method: :patch, class: "btn btn-outline-danger" %>
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
    <div class="card mb-3">
      <div class="card-header">
        <h5>Your Profile</h5>
      </div>
      <div class="card-body">
        <p><strong>Name:</strong> <%= current_user.respond_to?(:full_name) ? current_user.full_name : "#{current_user.first_name} #{current_user.last_name}" %></p>
        <p><strong>Email:</strong> <%= current_user.email %></p>
        <p><strong>Company:</strong> <%= current_user.company %></p>
        <% if current_user.phone %>
          <p><strong>Phone:</strong> <%= current_user.phone %></p>
        <% end %>
      </div>
    </div>

    <% if defined?(@my_events) && @my_events&.any? %>
      <div class="card">
        <div class="card-header">
          <h6>My Events</h6>
        </div>
        <div class="card-body">
          <% @my_events.each do |event| %>
            <% participant = current_user.event_participants.find_by(event: event) if current_user.respond_to?(:event_participants) %>
            <div class="mb-2">
              <strong><%= event.name %></strong><br>
              <small class="text-muted"><%= event.event_date&.strftime("%b %d") %></small>
              <% if participant %>
                <br>
                <span class="badge bg-<%= (participant.rsvp_status.to_s == 'yes' || participant.rsvp_status.to_s == '1') ? 'success' : 'secondary' %>">
                  <%= participant.rsvp_status.respond_to?(:humanize) ? participant.rsvp_status.humanize : participant.rsvp_status.to_s.humanize %>
                </span>
                <% if participant.role.to_s == 'vendor' || participant.role.to_s == '1' %>
                  <span class="badge bg-warning">Vendor</span>
                <% elsif participant.role.to_s == 'organizer' || participant.role.to_s == '2' %>
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

echo "✓ Universal dashboard view created"

# 10. Create environment validation with improved error handling
echo "Creating environment validation..."
cat > lib/environment_validator.rb << 'VALIDATOR_EOF'
# Environment Validation Script
class EnvironmentValidator
  def self.validate!
    puts "Validating environment configuration..."
    
    # Check critical models exist
    raise "User model not found" unless defined?(User)
    
    # Check admin user exists
    admin_count = count_admin_users
    puts "Admin users found: #{admin_count}"
    
    if admin_count == 0
      puts "WARNING: No admin users found. Creating default admin..."
      create_default_admin
    else
      puts "Admin users already exist - skipping creation"
    end
    
    puts "Environment validation complete!"
  end
  
  private
  
  def self.count_admin_users
    if User.respond_to?(:admin)
      User.admin.count
    elsif User.defined_enums.key?('role')
      User.where(role: User.defined_enums['role']['admin']).count
    else
      User.where(role: 'admin').count
    end
  rescue
    0
  end
  
  def self.create_default_admin
    # Check if admin email already exists
    existing_admin = User.find_by(email: 'admin@ptc.com')
    
    if existing_admin
      puts "Admin user already exists with email admin@ptc.com"
      # Update role if needed
      if existing_admin.respond_to?(:admin?) && !existing_admin.admin?
        if User.defined_enums.key?('role')
          existing_admin.update!(role: 'admin')
        else
          existing_admin.update!(role: 'admin')
        end
        puts "Updated existing user to admin role"
      end
      return
    end
    
    admin_attrs = {
      first_name: 'Admin',
      last_name: 'User',
      email: 'admin@ptc.com',
      password: 'password123',
      company: 'PTC',
      phone: '503-555-0100'
    }
    
    # Set role based on model structure
    if User.defined_enums.key?('role')
      admin_attrs[:role] = 'admin'  # Rails will convert to enum value
    else
      admin_attrs[:role] = 'admin'
    end
    
    # Set other default fields if they exist
    admin_attrs[:rsvp_status] = 'pending' if User.column_names.include?('rsvp_status')
    admin_attrs[:text_capable] = true if User.column_names.include?('text_capable')
    admin_attrs[:invited_at] = 2.weeks.ago if User.column_names.include?('invited_at')
    admin_attrs[:registered_at] = 1.week.ago if User.column_names.include?('registered_at')
    
    begin
      User.create!(admin_attrs)
      puts "Created admin user: admin@ptc.com / password123"
    rescue ActiveRecord::RecordInvalid => e
      puts "Could not create admin user: #{e.message}"
      # Try to find existing user and promote to admin
      existing_user = User.first
      if existing_user
        if User.defined_enums.key?('role')
          existing_user.update!(role: 'admin')
        else
          existing_user.update!(role: 'admin')
        end
        puts "Promoted existing user #{existing_user.email} to admin"
      end
    end
  end
end
VALIDATOR_EOF

echo "✓ Environment validator created"

# 11. Run post-setup verification
echo ""
echo "Running post-setup verification..."
ruby -e "
require_relative 'config/environment'
require_relative 'lib/environment_validator'
EnvironmentValidator.validate!
"

echo ""
echo "SUCCESS! Complete environment detection and setup completed!"
echo ""
echo "FEATURES CONFIGURED:"
echo "✓ Universal admin detection (works with enums or strings)"
echo "✓ Development asset caching disabled"
echo "✓ Rails 7 JavaScript structure with importmaps"
echo "✓ Admin helper methods for flexible role checking"
echo "✓ Fixed RSVP functionality with proper PATCH requests"
echo "✓ Universal layout with proper sign out handling"
echo "✓ Admin base controller with universal authorization"
echo "✓ Dashboard view with enum-aware RSVP buttons"
echo "✓ Environment validation with fallback admin creation"
echo "✓ RSVP controller with legacy support"
echo ""
echo "NEXT STEPS:"
echo "1. Test admin access at: http://localhost:3000/admin"
echo "2. Test user dashboard and RSVP functionality at: http://localhost:3000"
echo "3. Login credentials: admin@ptc.com / password123"
echo ""
echo "Admin buttons should now be visible for admin users!"