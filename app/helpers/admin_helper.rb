module AdminHelper
  def user_is_admin?(user)
    return false unless user
    
    # Handle both string and enum-based role fields
    if user.respond_to?(:admin?)
      user.admin?
    elsif user.respond_to?(:role)
      case user.role
      when String
        user.role == 'admin'
      when Integer
        # Handle enum where admin = 1 (common Rails pattern)
        user.role == 1 || (user.respond_to?(:admin?) && user.admin?)
      else
        false
      end
    else
      false
    end
  end
  
  def role_display_name(user)
    return 'Unknown' unless user&.role
    
    if user.respond_to?(:admin?) && user.admin?
      'Admin'
    elsif user.role.respond_to?(:humanize)
      user.role.humanize
    else
      user.role.to_s.humanize
    end
  end
end
