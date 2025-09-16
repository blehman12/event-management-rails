#Fix user issue NoMethodError in Admin::bulk delete

#!/bin/bash

# Script 16 After Run Fix - User Issues
# Fixes common user interface issues after running the main scripts

set -e

APP_NAME="${1:-ev1}"
echo "Fixing user interface issues..."

cd "$APP_NAME"

echo "========================================="
echo "Applying Post-Installation Fixes"
echo "========================================="

ls  app/controllers/admin/bulk_users_controller.rb


sed -i 's/users_to_delete.destroy_all/users_to_delete.each(\&:destroy)/' app/controllers/admin/bulk_users_controller.rb
#Fix user issue NoMethodError in Admin::Users#show
sed -i 's#<%= @user\.last_sign_in_at&\.strftime("%B %d, %Y") || "Never" %>#<%= @user.respond_to?(:last_sign_in_at) \&\& @user.last_sign_in_at ? @user.last_sign_in_at.strftime("%B %d, %Y") : "Never" %>#' app/views/admin/users/show.html.erb


