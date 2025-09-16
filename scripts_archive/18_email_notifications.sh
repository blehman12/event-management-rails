#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Setting up email notification system..."

cd "$APP_NAME"

# Add email gems to Gemfile
cat >> Gemfile << 'GEMFILE_EOF'

# Email and background jobs
gem 'sidekiq'
gem 'sidekiq-web'
gem 'redis'
gem 'premailer-rails'
gem 'nokogiri'
GEMFILE_EOF

bundle install

# Generate mailer
rails generate mailer EventNotificationMailer rsvp_confirmation event_reminder event_update

# Update Event Notification Mailer
cat > app/mailers/event_notification_mailer.rb << 'MAILER_EOF'
class EventNotificationMailer < ApplicationMailer
  default from: 'noreply@ptcwindchill-events.com'

  def rsvp_confirmation(event_participant)
    @user = event_participant.user
    @event = event_participant.event
    @participant = event_participant
    
    mail(
      to: @user.email,
      subject: "RSVP Confirmation: #{@event.name}"
    )
  end

  def event_reminder(event_participant)
    @user = event_participant.user
    @event = event_participant.event
    @participant = event_participant
    
    mail(
      to: @user.email,
      subject: "Reminder: #{@event.name} - #{@event.event_date.strftime('%B %d, %Y')}"
    )
  end

  def event_update(event_participant, changes)
    @user = event_participant.user
    @event = event_participant.event
    @participant = event_participant
    @changes = changes
    
    mail(
      to: @user.email,
      subject: "Event Update: #{@event.name}"
    )
  end

  def vendor_welcome(event_participant)
    @user = event_participant.user
    @event = event_participant.event
    @participant = event_participant
    
    mail(
      to: @user.email,
      subject: "Welcome Vendor: #{@event.name}"
    )
  end
end
MAILER_EOF

# Create email templates
mkdir -p app/views/event_notification_mailer

cat > app/views/event_notification_mailer/rsvp_confirmation.html.erb << 'RSVP_TEMPLATE_EOF'
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background-color: #0066cc; color: white; padding: 20px; text-align: center;">
    <h1>PTC Windchill Event</h1>
  </div>
  
  <div style="padding: 30px;">
    <h2>RSVP Confirmation</h2>
    
    <p>Hi <%= @user.first_name %>,</p>
    
    <p>Thank you for your RSVP to <strong><%= @event.name %></strong>!</p>
    
    <div style="background-color: #f8f9fa; padding: 20px; border-left: 4px solid #0066cc; margin: 20px 0;">
      <p><strong>Your Status:</strong> <span style="color: <%= @participant.rsvp_status == 'yes' ? '#28a745' : @participant.rsvp_status == 'maybe' ? '#ffc107' : '#dc3545' %>; font-weight: bold;"><%= @participant.rsvp_status.humanize %></span></p>
      <% if @participant.vendor? %>
        <p><strong>Role:</strong> <span style="color: #fd7e14; font-weight: bold;">Vendor</span></p>
      <% elsif @participant.organizer? %>
        <p><strong>Role:</strong> <span style="color: #28a745; font-weight: bold;">Organizer</span></p>
      <% end %>
    </div>
    
    <h3>Event Details:</h3>
    <ul style="line-height: 1.6;">
      <li><strong>Date:</strong> <%= @event.event_date.strftime('%A, %B %d, %Y') %></li>
      <li><strong>Time:</strong> <%= @event.start_time&.strftime('%I:%M %p') %> - <%= @event.end_time&.strftime('%I:%M %p') %></li>
      <li><strong>Location:</strong> <%= @event.venue.full_address %></li>
      <li><strong>RSVP Deadline:</strong> <%= @event.rsvp_deadline.strftime('%B %d, %Y at %I:%M %p') %></li>
    </ul>
    
    <% if @event.description.present? %>
      <h3>About This Event:</h3>
      <p style="line-height: 1.6;"><%= simple_format(@event.description) %></p>
    <% end %>
    
    <% if @participant.rsvp_status == 'yes' %>
      <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 0; color: #155724;"><strong>Great! We look forward to seeing you there.</strong></p>
      </div>
    <% end %>
    
    <p style="margin-top: 30px;">
      Need to change your RSVP? <a href="<%= root_url %>" style="color: #0066cc;">Visit our event portal</a>
    </p>
  </div>
  
  <div style="background-color: #f8f9fa; padding: 20px; text-align: center; color: #6c757d; font-size: 12px;">
    <p>PTC Windchill Community Events<br>
    This is an automated message. Please do not reply to this email.</p>
  </div>
</div>
RSVP_TEMPLATE_EOF

cat > app/views/event_notification_mailer/event_reminder.html.erb << 'REMINDER_TEMPLATE_EOF'
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background-color: #fd7e14; color: white; padding: 20px; text-align: center;">
    <h1>Event Reminder</h1>
  </div>
  
  <div style="padding: 30px;">
    <h2><%= @event.name %></h2>
    
    <p>Hi <%= @user.first_name %>,</p>
    
    <p>This is a friendly reminder about the upcoming PTC Windchill event you're attending:</p>
    
    <div style="background-color: #fff3cd; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <h3 style="margin-top: 0; color: #856404;">Event Details:</h3>
      <ul style="line-height: 1.8; color: #856404;">
        <li><strong>Date:</strong> <%= @event.event_date.strftime('%A, %B %d, %Y') %></li>
        <li><strong>Time:</strong> <%= @event.start_time&.strftime('%I:%M %p') %> - <%= @event.end_time&.strftime('%I:%M %p') %></li>
        <li><strong>Location:</strong> <%= @event.venue.full_address %></li>
      </ul>
    </div>
    
    <% if @participant.vendor? %>
      <div style="background-color: #d1ecf1; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 0; color: #0c5460;"><strong>Vendor Information:</strong> Please arrive 30 minutes early for setup. Contact the event organizer if you need assistance.</p>
      </div>
    <% end %>
    
    <p>We're looking forward to seeing you there!</p>
    
    <p style="margin-top: 30px;">
      Questions? <a href="<%= root_url %>" style="color: #fd7e14;">Visit our event portal</a>
    </p>
  </div>
</div>
REMINDER_TEMPLATE_EOF

# Update EventParticipant model to send notifications
cat >> app/models/event_participant.rb << 'PARTICIPANT_NOTIFY_EOF'

  after_update :send_rsvp_notification, if: :saved_change_to_rsvp_status?
  after_update :send_vendor_welcome, if: :saved_change_to_role_and_is_vendor?

  private

  def send_rsvp_notification
    EventNotificationMailer.rsvp_confirmation(self).deliver_now
  end

  def send_vendor_welcome
    EventNotificationMailer.vendor_welcome(self).deliver_now if vendor?
  end

  def saved_change_to_role_and_is_vendor?
    saved_change_to_role? && vendor?
  end
PARTICIPANT_NOTIFY_EOF

# Add email configuration
cat >> config/environments/development.rb << 'EMAIL_CONFIG_EOF'

  # Email configuration for development
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'localhost',
    port: 1025,
    domain: 'localhost'
  }
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
EMAIL_CONFIG_EOF

echo "Email notification system setup completed!"
echo "For development, run: gem install mailcatcher && mailcatcher"
echo "Then visit http://localhost:1080 to see sent emails"
