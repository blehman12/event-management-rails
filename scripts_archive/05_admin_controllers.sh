#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 5: Creating admin controllers"

cd "$APP_NAME"
mkdir -p app/controllers/admin

# Admin Base Controller
cat > app/controllers/admin/base_controller.rb << 'EOF'
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  private

  def ensure_admin
    redirect_to root_path unless current_user&.admin?
  end
end
EOF

# Admin Dashboard
cat > app/controllers/admin/dashboard_controller.rb << 'EOF'
class Admin::DashboardController < Admin::BaseController
  def index
    @total_invited = User.invited.count
    @total_registered = User.registered.count
    @rsvp_counts = {
      yes: User.yes.count,
      no: User.no.count,
      maybe: User.maybe.count,
      pending: User.pending.count
    }
    @event = Event.first
    @recent_users = User.order(created_at: :desc).limit(5)
  end
end
EOF

# FIXED: Admin Users Controller with full CRUD
cat > app/controllers/admin/users_controller.rb << 'EOF'
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.all.order(:last_name, :first_name)
  end

  def show
  end

  def edit
  end

  def update
    if user_params[:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: 'User was successfully deleted.'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :company, 
                                  :text_capable, :role, :rsvp_status, :password, :password_confirmation)
  end
end
EOF

# Admin Events Controller
cat > app/controllers/admin/events_controller.rb << 'EOF'
class Admin::EventsController < Admin::BaseController
  def index
    @events = Event.all.order(:event_date)
  end
end
EOF

# Admin Venues Controller
cat > app/controllers/admin/venues_controller.rb << 'EOF'
class Admin::VenuesController < Admin::BaseController
  def index
    @venues = Venue.all.order(:name)
  end
end
EOF

echo "✓ Admin controllers created"
