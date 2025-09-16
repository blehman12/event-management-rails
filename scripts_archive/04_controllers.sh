#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 4: Creating controllers"

cd "$APP_NAME"
rails generate controller Dashboard index

# Application Controller
cat > app/controllers/application_controller.rb << 'EOF'
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone, :company, :text_capable])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :company, :text_capable])
  end
end
EOF

# FIXED: Dashboard Controller with proper authentication
cat > app/controllers/dashboard_controller.rb << 'EOF'
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @event = Event.upcoming.first || Event.first
    @user_rsvp_status = current_user.rsvp_status
    @deadline_passed = @event&.rsvp_deadline && @event.rsvp_deadline < Time.current
    @total_attendees = User.yes.count if @event
    @spots_remaining = @event&.spots_remaining
  end
end
EOF

# RSVP Controller
cat > app/controllers/rsvp_controller.rb << 'EOF'
class RsvpController < ApplicationController
  before_action :authenticate_user!

  def update
    @event = Event.upcoming.first || Event.first
    
    if @event&.rsvp_open?
      current_user.update(rsvp_status: params[:status])
      current_user.update(registered_at: Time.current) if current_user.registered_at.nil?
      redirect_to dashboard_path, notice: "RSVP updated!"
    else
      redirect_to dashboard_path, alert: "RSVP deadline has passed."
    end
  end
end
EOF

# Routes
cat > config/routes.rb << 'EOF'
Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'
  get 'dashboard', to: 'dashboard#index'
  patch 'rsvp/:status', to: 'rsvp#update', as: :rsvp

  namespace :admin do
    root 'dashboard#index'
    resources :users
    resources :venues
    resources :events
  end
end
EOF

echo "✓ Basic controllers created"
