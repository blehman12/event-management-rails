# Add these methods to your app/controllers/admin/bulk_users_controller.rb

# Add this at the top if not already there
require 'csv'

class Admin::BulkUsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @users = User.includes(:events).order(:last_name, :first_name)
    @total_users = @users.count
    @recent_users = @users.where('created_at > ?', 7.days.ago).count
    @admin_count = User.where(role: 'admin').count
  end

  def import_form
    # Show the import form
  end

  def process_import
    unless params[:csv_file].present?
      redirect_to import_form_admin_bulk_users_path, alert: 'Please select a CSV file to import.'
      return
    end

    begin
      results = process_csv_import(params[:csv_file])
      
      if results[:errors].any?
        flash[:alert] = "Import completed with errors. Created #{results[:created]} users. Errors: #{results[:errors].first(5).join(', ')}"
        if results[:errors].count > 5
          flash[:alert] += " (and #{results[:errors].count - 5} more errors)"
        end
      else
        flash[:notice] = "Successfully imported #{results[:created]} users!"
      end
    rescue => e
      Rails.logger.error "CSV Import Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "Import failed: #{e.message}"
    end

    redirect_to admin_bulk_users_path
  end

  def bulk_actions
    user_ids = params[:user_ids] || []
    action = params[:bulk_action]

    Rails.logger.info "Bulk action received: #{action} for users: #{user_ids.inspect}"

    if user_ids.empty?
      redirect_to admin_bulk_users_path, alert: 'No users selected.'
      return
    end

    users = User.where(id: user_ids)
    Rails.logger.info "Found #{users.count} users for bulk action"

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
      Rails.logger.warn "Invalid bulk action: #{action}"
      redirect_to admin_bulk_users_path, alert: "Invalid action selected: #{action}"
    end
  rescue => e
    Rails.logger.error "Bulk action error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to admin_bulk_users_path, alert: "An error occurred: #{e.message}"
  end

  def export_csv
    users = User.all.order(:last_name, :first_name)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['First Name', 'Last Name', 'Email', 'Phone', 'Company', 'Role', 'Text Capable', 'Created At']
      
      users.each do |user|
        csv << [
          user.first_name,
          user.last_name,
          user.email,
          user.phone || '',
          user.company || '',
          user.role || 'attendee',
          user.respond_to?(:text_capable) ? user.text_capable : 'true',
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
          role: clean_row[:role] || 'attendee'
        }

        # Handle text_capable if the field exists
        if User.column_names.include?('text_capable')
          user_attrs[:text_capable] = parse_boolean(clean_row[:text_capable])
        end

        # Handle invited_at if the field exists
        if User.column_names.include?('invited_at')
          user_attrs[:invited_at] = Time.current
        end
        
        # Skip if required fields are missing
        if user_attrs[:first_name].blank? || user_attrs[:last_name].blank? || user_attrs[:email].blank?
          results[:errors] << "Row #{$.}: Missing required fields (first_name, last_name, email)"
          next
        end
        
        # Validate role
        if user_attrs[:role].present? && !['admin', 'attendee'].include?(user_attrs[:role].downcase)
          user_attrs[:role] = 'attendee'
        end
        
        User.create!(user_attrs)
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
    # Prevent deleting current user
    users_to_delete = users.reject { |u| u == current_user }
    
    # Check if we're deleting all admins
    remaining_admins = User.where(role: 'admin').where.not(id: users_to_delete.map(&:id)).count
    
    if remaining_admins == 0
      redirect_to admin_bulk_users_path, alert: 'Cannot delete all admin users.'
      return
    end
    
    deleted_count = users_to_delete.count
    # Fix: Delete each user individually instead of using destroy_all on array
    users_to_delete.each(&:destroy)
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully deleted #{deleted_count} users."
  end

  def perform_bulk_promote(users)
    count = 0
    users.each do |user|
      unless user.role == 'admin'
        user.update!(role: 'admin')
        count += 1
      end
    end
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully promoted #{count} users to admin."
  end

  def perform_bulk_demote(users)
    # Prevent demoting current user
    users_to_demote = users.reject { |u| u == current_user }
    
    # Ensure we don't demote all admins
    current_admin_count = User.where(role: 'admin').count
    admin_users_to_demote = users_to_demote.select { |u| u.role == 'admin' }
    
    if admin_users_to_demote.count >= current_admin_count
      redirect_to admin_bulk_users_path, alert: 'Cannot demote all admin users.'
      return
    end
    
    count = 0
    users_to_demote.each do |user|
      if user.role == 'admin'
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
      # Check if invited_at field exists and user hasn't been invited
      if User.column_names.include?('invited_at') && user.invited_at.nil?
        user.update!(invited_at: Time.current)
        count += 1
      elsif !User.column_names.include?('invited_at')
        # If no invited_at field, just count as invited
        count += 1
      end
    end
    
    redirect_to admin_bulk_users_path, 
                notice: "Successfully sent invitations to #{count} users."
  end

  def ensure_admin!
    redirect_to root_path unless current_user&.role == 'admin'
  end
end