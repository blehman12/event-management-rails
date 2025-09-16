# Environment Validation Script
class EnvironmentValidator
  def self.validate!
    puts "Validating environment configuration..."
    
    # Check critical models exist
    raise "User model not found" unless defined?(User)
    
    # Check admin user exists
    admin_count = count_admin_users
    puts "Admin users found: #{admin_count}"
    
    if admin_count == 0
      puts "WARNING: No admin users found. Creating default admin..."
      create_default_admin
    else
      puts "Admin users already exist - skipping creation"
    end
    
    puts "Environment validation complete!"
  end
  
  private
  
  def self.count_admin_users
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
  
  def self.create_default_admin
    # Check if admin email already exists
    existing_admin = User.find_by(email: 'admin@ptc.com')
    
    if existing_admin
      puts "Admin user already exists with email admin@ptc.com"
      # Update role if needed
      if existing_admin.respond_to?(:admin?) && !existing_admin.admin?
        if User.defined_enums.key?('role')
          existing_admin.update!(role: 'admin')
        else
          existing_admin.update!(role: 'admin')
        end
        puts "Updated existing user to admin role"
      end
      return
    end
    
    admin_attrs = {
      first_name: 'Admin',
      last_name: 'User',
      email: 'admin@ptc.com',
      password: 'password123',
      company: 'PTC',
      phone: '503-555-0100'
    }
    
    # Set role based on model structure
    if User.defined_enums.key?('role')
      admin_attrs[:role] = 'admin'  # Rails will convert to enum value
    else
      admin_attrs[:role] = 'admin'
    end
    
    # Set other default fields if they exist
    admin_attrs[:rsvp_status] = 'pending' if User.column_names.include?('rsvp_status')
    admin_attrs[:text_capable] = true if User.column_names.include?('text_capable')
    admin_attrs[:invited_at] = 2.weeks.ago if User.column_names.include?('invited_at')
    admin_attrs[:registered_at] = 1.week.ago if User.column_names.include?('registered_at')
    
    begin
      User.create!(admin_attrs)
      puts "Created admin user: admin@ptc.com / password123"
    rescue ActiveRecord::RecordInvalid => e
      puts "Could not create admin user: #{e.message}"
      # Try to find existing user and promote to admin
      existing_user = User.first
      if existing_user
        if User.defined_enums.key?('role')
          existing_user.update!(role: 'admin')
        else
          existing_user.update!(role: 'admin')
        end
        puts "Promoted existing user #{existing_user.email} to admin"
      end
    end
  end
end
