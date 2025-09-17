class Admin::BulkUsersController < Admin::BaseController
  require 'csv'
  
  def index
    @users = User.all.order(:last_name, :first_name)
    @pagy, @users = pagy(@users, items: 20) if defined?(Pagy)
  end
  
  def import_form
    # Show CSV import form
  end
  
  def import_csv
    unless params[:csv_file].present?
      redirect_to import_form_admin_bulk_users_path, alert: 'Please select a CSV file.'
      return
    end
    
    csv_file = params[:csv_file]
    
    begin
      results = process_csv_import(csv_file)
      
      if results[:errors].any?
        flash[:alert] = "Import completed with errors. Created #{results[:created]} users. Errors: #{results[:errors].first(5).join('; ')}"
      else
        flash[:notice] = "Successfully imported #{results[:created]} users."
      end
      
    rescue => e
      flash[:alert] = "Import failed: #{e.message}"
    end
    
    redirect_to admin_bulk_users_path
  end
  
  def bulk_actions
    user_ids = params[:user_ids]
    action = params[:bulk_action]
    
    unless user_ids.present? && action.present?
      redirect_to admin_bulk_users_path, alert: 'Please select users and an action.'
      return
    end
    
    unless user_ids.is_a?(Array)
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
      csv << ['First Name', 'Last Name', 'Email', 'Phone', 'Company', 'Role', 'RSVP Status', 'Invited At', 'Created At']
      
      users.each do |user|
        csv << [
          user.first_name,
          user.last_name,
          user.email,
          user.phone,
          user.company,
          user.role.humanize,
          user.respond_to?(:rsvp_status) ? user.rsvp_status.humanize : 'N/A',
          user.respond_to?(:invited_at) && user.invited_at ? user.invited_at.strftime('%Y-%m-%d %H:%M') : 'Never',
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
    return true if value.to_s.downcase.in?(['true', '1', 'yes', 'y'])
    false
  end
  
  def perform_bulk_delete(users)
    count = users.count
    users.destroy_all
    redirect_to admin_bulk_users_path, 
                notice: "Successfully deleted #{count} users."
  end
  
  def perform_bulk_promote(users)
    count = 0
    users_to_promote = users.select { |user| !user.admin? }
    
    if users_to_promote.empty?
      redirect_to admin_bulk_users_path, 
                  alert: "No users to promote (all selected users are already admins)."
      return
    end
    
    users_to_promote.each do |user|
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
    users_to_demote = users.select { |user| user.admin? }
    
    if users_to_demote.empty?
      redirect_to admin_bulk_users_path, 
                  alert: "No admin users selected to demote."
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
    email_count = 0
    
    # Get the most recent event instead of looking for is_active
    current_event = Event.order(:event_date).last
    
    users.each do |user|
      # Update invited_at timestamp
      if user.respond_to?(:invited_at) && user.invited_at.nil?
        user.update!(invited_at: Time.current)
        count += 1
        
        # Send invitation email if we have an event
        if current_event
          begin
            InvitationMailer.event_invitation(user, current_event).deliver_now
            email_count += 1
          rescue => e
            Rails.logger.error "Failed to send invitation email to #{user.email}: #{e.message}"
          end
        end
      end
    end
    
    if email_count > 0
      redirect_to admin_bulk_users_path, 
                  notice: "Successfully sent invitations to #{count} users. #{email_count} emails delivered."
    else
      redirect_to admin_bulk_users_path, 
                  notice: "Successfully marked #{count} users as invited. No emails sent (no event found)."
    end
  end
end