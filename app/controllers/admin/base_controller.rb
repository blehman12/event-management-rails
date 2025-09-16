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
