# Create app/controllers/admin/checkin_controller.rb

class Admin::CheckinController < Admin::BaseController
  before_action :set_event
  
  # Live check-in dashboard
  def checkin_dashboard
    @participants = @event.event_participants.includes(:user).order('users.last_name, users.first_name')
    @checked_in_count = @participants.checked_in.count
    @total_rsvped = @participants.where(rsvp_status: [:yes, :maybe]).count
    @not_checked_in = @participants.not_checked_in.where(rsvp_status: [:yes, :maybe])
    @recent_checkins = @participants.checked_in.order(checked_in_at: :desc).limit(10)
  end
  
  # Generate QR codes page
  def generate_qr_codes
    @participants = @event.event_participants.includes(:user)
                          .where(rsvp_status: [:yes, :maybe])
                          .order('users.last_name, users.first_name')
    @missing_tokens = @participants.where(qr_code_token: nil).count
  end
  
  # Actually create the QR tokens
  def create_qr_codes
    participants = @event.event_participants.where(rsvp_status: [:yes, :maybe])
    generated_count = 0
    
    participants.find_each do |participant|
      if participant.qr_code_token.blank?
        participant.generate_qr_code_token
        generated_count += 1
      end
    end
    
    redirect_to generate_qr_codes_admin_event_path(@event), 
                notice: "Generated QR codes for #{generated_count} participants."
  end
  
  # Printable badges/QR codes
  def print_badges
    @participants = @event.event_participants.includes(:user)
                          .where(rsvp_status: [:yes, :maybe])
                          .where.not(qr_code_token: nil)
                          .order('users.last_name, users.first_name')
    
    if @participants.none?
      redirect_to generate_qr_codes_admin_event_path(@event),
                  alert: "No QR codes available. Generate QR codes first."
      return
    end
    
    respond_to do |format|
      format.html
      format.pdf do
        # PDF generation would go here if needed
        redirect_to print_badges_admin_event_path(@event), 
                    alert: "PDF generation not yet implemented."
      end
    end
  end
  
  # Bulk manual check-in form
  def bulk_checkin
    @participants = @event.event_participants.includes(:user)
                          .where(rsvp_status: [:yes, :maybe])
                          .not_checked_in
                          .order('users.last_name, users.first_name')
  end
  
  # Process bulk check-in
  def process_bulk_checkin
    participant_ids = params[:participant_ids] || []
    
    if participant_ids.empty?
      redirect_to bulk_checkin_admin_event_path(@event),
                  alert: "No participants selected."
      return
    end
    
    checked_in_count = 0
    participants = @event.event_participants.where(id: participant_ids)
    
    participants.each do |participant|
      unless participant.checked_in?
        participant.check_in!(method: :bulk, checked_in_by: current_user)
        checked_in_count += 1
      end
    end
    
    redirect_to checkin_dashboard_admin_event_path(@event),
                notice: "Checked in #{checked_in_count} participants."
  end
  
  # Export check-in data
  def export_checkin_data
    require 'csv'
    
    participants = @event.event_participants.includes(:user).order('users.last_name, users.first_name')
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Name', 'Email', 'RSVP Status', 'Checked In?', 'Check-in Time', 'Check-in Method', 'Checked In By']
      
      participants.each do |participant|
        csv << [
          "#{participant.user.first_name} #{participant.user.last_name}",
          participant.user.email,
          participant.rsvp_status_text,
          participant.checked_in? ? 'Yes' : 'No',
          participant.checked_in? ? participant.checked_in_at.strftime('%m/%d/%Y %I:%M %p') : '',
          participant.checked_in? ? participant.check_in_method_text : '',
          participant.checked_in_by&.name || ''
        ]
      end
    end
    
    filename = "#{@event.name.parameterize}-checkin-data-#{Date.current.strftime('%Y%m%d')}.csv"
    
    send_data csv_data,
              filename: filename,
              type: 'text/csv',
              disposition: 'attachment'
  end
  
  # AJAX endpoint for live dashboard updates
  def dashboard_stats
    stats = {
      checked_in_count: @event.event_participants.checked_in.count,
      total_rsvped: @event.event_participants.where(rsvp_status: [:yes, :maybe]).count,
      recent_checkins: @event.event_participants.checked_in
                            .includes(:user)
                            .order(checked_in_at: :desc)
                            .limit(5)
                            .map do |p|
                              {
                                name: "#{p.user.first_name} #{p.user.last_name}",
                                time: p.checked_in_at.strftime('%I:%M %p'),
                                method: p.check_in_method_text
                              }
                            end
    }
    
    render json: stats
  end
  
  private
  
  def set_event
    @event = Event.find(params[:id])
  end
end