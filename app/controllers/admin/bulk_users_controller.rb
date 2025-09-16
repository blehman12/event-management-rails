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
    users_to_delete.each(&:destroy)
    
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
