// Admin Safety Features
document.addEventListener('DOMContentLoaded', function() {
  // Find role select elements in admin forms
  const roleSelects = document.querySelectorAll('select[name*="[role]"]');
  
  roleSelects.forEach(function(select) {
    // Store the original role value
    const originalRole = select.value;
    
    select.addEventListener('change', function() {
      const newRole = this.value;
      
      // Check if we're demoting an admin
      if (originalRole === 'admin' && newRole !== 'admin') {
        const confirmed = confirm(
          '⚠️ WARNING: You are removing admin privileges!\n\n' +
          'This user will lose access to:\n' +
          '• Admin dashboard\n' +
          '• User management\n' +
          '• Event management\n' +
          '• Venue management\n\n' +
          'Are you sure you want to continue?'
        );
        
        if (!confirmed) {
          // Reset to original value if they cancel
          this.value = originalRole;
          return false;
        }
      }
      
      // Check if we're promoting someone to admin
      if (originalRole !== 'admin' && newRole === 'admin') {
        const confirmed = confirm(
          '🔑 You are granting admin privileges to this user.\n\n' +
          'They will gain access to:\n' +
          '• Admin dashboard\n' +
          '• User management\n' +
          '• Event management\n' +
          '• Venue management\n\n' +
          'Are you sure you want to continue?'
        );
        
        if (!confirmed) {
          // Reset to original value if they cancel
          this.value = originalRole;
          return false;
        }
      }
    });
  });
  
  // Prevent self-demotion
  const currentUserEmail = document.body.dataset.currentUserEmail;
  const editUserEmail = document.body.dataset.editUserEmail;
  
  if (currentUserEmail && editUserEmail && currentUserEmail === editUserEmail) {
    roleSelects.forEach(function(select) {
      select.addEventListener('change', function() {
        if (this.value !== 'admin') {
          alert('⛔ You cannot remove your own admin privileges!\n\nAsk another admin to change your role if needed.');
          this.value = 'admin';
          return false;
        }
      });
    });
  }
});
