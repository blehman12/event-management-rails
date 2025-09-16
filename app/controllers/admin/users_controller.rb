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
