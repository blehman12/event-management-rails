#!/usr/bin/env ruby

# Script to fix link_to with method: :delete to button_to
# Run from Rails project root: ruby fix_delete_buttons.rb

require 'fileutils'

# Files that need fixing based on grep results
FILES_TO_FIX = [
  'app/views/admin/events/edit.html.erb',
  'app/views/admin/venues/edit.html.erb', 
  'app/views/admin/venues/index.html.erb',
  'app/views/admin/events/participants.html.erb',
  'app/views/admin/event_participants/index.html.erb',
  'app/views/admin/users/show.html.erb'
]

def backup_file(file_path)
  backup_path = "#{file_path}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  FileUtils.cp(file_path, backup_path)
  puts "  Created backup: #{backup_path}"
end

def fix_delete_links(content)
  # Pattern to match link_to with method: :delete
  # This handles various formatting styles and captures the important parts
  content.gsub(/<%=\s*link_to\s+"([^"]+)",\s*([^,]+),\s*method:\s*:delete(?:\s*,\s*([^%>]+))?([^%>]*)\s*%>/m) do |match|
    text = $1
    path = $2
    middle_params = $3
    end_params = $4
    
    # Build the new button_to
    new_button = "<%= button_to \"#{text}\", #{path}, method: :delete"
    
    # Add form_class for inline display
    new_button += ", form_class: \"d-inline\""
    
    # Add any additional parameters that were in the original
    if middle_params && !middle_params.strip.empty?
      # Clean up the parameters - remove leading/trailing whitespace and commas
      clean_params = middle_params.strip.gsub(/^,\s*/, '').gsub(/,\s*$/, '')
      new_button += ", #{clean_params}" unless clean_params.empty?
    end
    
    if end_params && !end_params.strip.empty?
      clean_end = end_params.strip.gsub(/^,\s*/, '').gsub(/,\s*$/, '')
      new_button += ", #{clean_end}" unless clean_end.empty?
    end
    
    new_button += " %>"
    
    puts "    Fixed: #{match.gsub(/\s+/, ' ').strip}"
    puts "    To:    #{new_button}"
    puts ""
    
    new_button
  end
end

def process_file(file_path)
  unless File.exist?(file_path)
    puts "Skipping #{file_path} - file not found"
    return false
  end
  
  puts "Processing: #{file_path}"
  
  # Create backup
  backup_file(file_path)
  
  # Read and process content
  content = File.read(file_path)
  original_content = content.dup
  
  # Fix the delete links
  new_content = fix_delete_links(content)
  
  # Check if any changes were made
  if new_content == original_content
    puts "  No changes needed in #{file_path}"
    return false
  end
  
  # Write the updated content
  File.write(file_path, new_content)
  puts "  Updated #{file_path}"
  puts ""
  
  true
end

# Main execution
puts "Rails Delete Button Fix Script"
puts "=" * 40
puts ""

changes_made = false

FILES_TO_FIX.each do |file_path|
  if process_file(file_path)
    changes_made = true
  end
end

puts ""
puts "=" * 40
if changes_made
  puts "Script completed! Files have been updated."
  puts "Backup files created with timestamp suffixes."
  puts ""
  puts "Test your application to ensure everything works correctly."
  puts "If issues occur, restore from backup files."
else
  puts "No changes were needed - all files already use button_to or don't have delete links."
end
puts ""