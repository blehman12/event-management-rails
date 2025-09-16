#!/usr/bin/env ruby

# Model Structure Detection Script
require_relative '../config/environment'

puts "\n" + "="*60
puts "ENVIRONMENT DETECTION REPORT"
puts "="*60

# Rails Version
puts "\nRAILS CONFIGURATION:"
puts "  Rails Version: #{Rails.version}"
puts "  Ruby Version: #{RUBY_VERSION}"
puts "  Environment: #{Rails.env}"

# User Model Detection
puts "\nUSER MODEL ANALYSIS:"
begin
  user_columns = User.column_names
  puts "  Available Fields: #{user_columns.join(', ')}"
  
  # Check for enums
  if User.respond_to?(:defined_enums)
    enums = User.defined_enums
    puts "  Enums Defined: #{enums.keys.join(', ')}" if enums.any?
    enums.each do |field, values|
      puts "    #{field}: #{values}"
    end
  else
    puts "  No enums detected"
  end
  
  # Check field types
  role_col = User.columns.find { |c| c.name == 'role' }
  puts "  Role Field Type: #{role_col&.type || 'NOT FOUND'}"
  
  # Check Devise modules
  devise_modules = User.devise_modules rescue []
  puts "  Devise Modules: #{devise_modules.join(', ')}"
  
  # Test admin detection
  admin_count = begin
    if User.respond_to?(:admin)
      User.admin.count
    elsif User.defined_enums.key?('role')
      User.where(role: User.defined_enums['role']['admin']).count
    else
      User.where(role: 'admin').count
    end
  rescue
    0
  end
  puts "  Admin Users Count: #{admin_count}"
  
rescue => e
  puts "  ERROR: #{e.message}"
end

# EventParticipant Model Detection
puts "\nEVENT_PARTICIPANT MODEL ANALYSIS:"
begin
  if defined?(EventParticipant)
    ep_columns = EventParticipant.column_names
    puts "  Available Fields: #{ep_columns.join(', ')}"
    
    # Check for enums
    if EventParticipant.respond_to?(:defined_enums)
      enums = EventParticipant.defined_enums
      puts "  Enums Defined: #{enums.keys.join(', ')}" if enums.any?
      enums.each do |field, values|
        puts "    #{field}: #{values}"
      end
    end
  else
    puts "  EventParticipant model not found"
  end
rescue => e
  puts "  ERROR: #{e.message}"
end

# Event Model Detection
puts "\nEVENT MODEL ANALYSIS:"
begin
  if defined?(Event)
    event_columns = Event.column_names
    puts "  Available Fields: #{event_columns.join(', ')}"
  else
    puts "  Event model not found"
  end
rescue => e
  puts "  ERROR: #{e.message}"
end

# Routes Analysis
puts "\nROUTES ANALYSIS:"
begin
  routes_output = `rails routes 2>/dev/null`
  has_rsvp_route = routes_output.include?('rsvp_path')
  has_admin_routes = routes_output.include?('admin_root')
  has_dashboard_route = routes_output.include?('dashboard#index')
  
  puts "  RSVP Routes: #{has_rsvp_route ? 'FOUND' : 'MISSING'}"
  puts "  Admin Routes: #{has_admin_routes ? 'FOUND' : 'MISSING'}"
  puts "  Dashboard Route: #{has_dashboard_route ? 'FOUND' : 'MISSING'}"
rescue => e
  puts "  ERROR analyzing routes: #{e.message}"
end

# Asset Pipeline Detection
puts "\nASSET PIPELINE ANALYSIS:"
importmap_exists = File.exist?('config/importmap.rb')
puts "  Importmap Config: #{importmap_exists ? 'EXISTS' : 'MISSING'}"

manifest_exists = File.exist?('app/assets/config/manifest.js')
puts "  Asset Manifest: #{manifest_exists ? 'EXISTS' : 'MISSING'}"

js_dir_exists = Dir.exist?('app/javascript')
puts "  JavaScript Directory: #{js_dir_exists ? 'EXISTS' : 'MISSING'}"

# Development Config Analysis
puts "\nDEVELOPMENT CONFIG ANALYSIS:"
dev_config = File.read('config/environments/development.rb') rescue "FILE NOT FOUND"
has_digest_false = dev_config.include?('assets.digest = false')
has_debug_true = dev_config.include?('assets.debug = true')
puts "  Asset Digest Disabled: #{has_digest_false ? 'YES' : 'NO'}"
puts "  Asset Debug Enabled: #{has_debug_true ? 'YES' : 'NO'}"

# Controller Analysis
puts "\nCONTROLLER ANALYSIS:"
admin_controllers = Dir.glob('app/controllers/admin/*.rb').map { |f| File.basename(f, '.rb') }
puts "  Admin Controllers: #{admin_controllers.join(', ')}"

puts "\n" + "="*60
puts "DETECTION COMPLETE"
puts "="*60
