class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  # Add admin role checking if needed:
  # before_action :ensure_admin
  
  private
  
  # Uncomment if you have admin role checking:
  # def ensure_admin
  #   redirect_to root_path unless current_user&.admin?
  # end
end