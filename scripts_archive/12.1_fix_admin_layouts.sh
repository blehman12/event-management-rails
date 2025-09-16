# Backup current layout


cd ev1
pwd

cp app/views/layouts/application.html.erb app/views/layouts/application.html.erb.old



# Create new layout with admin buttons
cat > app/views/layouts/application.html.erb << 'LAYOUT_EOF'
<!DOCTYPE html>
<html>
  <head>
    <title>PTC Windchill Event</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
    
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  </head>

  <body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
      <div class="container">
        <%= link_to "PTC Windchill Event", root_path, class: "navbar-brand" %>
        
        <div class="navbar-nav ms-auto d-flex align-items-center">
          <% if user_signed_in? %>
            <span class="navbar-text me-3">Hello, <%= current_user.full_name %></span>
            <% if current_user.role == 'admin' %>
              <div class="d-flex align-items-center gap-2 me-3">
                <%= link_to "Dashboard", admin_root_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" %>
                <%= link_to "Events", admin_events_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" %>
                <%= link_to "Venues", admin_venues_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" %>
                <%= link_to "Users", admin_users_path, class: "badge bg-light text-primary text-decoration-none px-2 py-1" %>
              </div>
            <% end %>
            <%= link_to "Sign Out", destroy_user_session_path, data: { "turbo-method": :delete }, class: "nav-link" %>
          <% else %>
            <%= link_to "Sign In", new_user_session_path, class: "nav-link" %>
          <% end %>
        </div>
      </div>
    </nav>

    <main class="container mt-4">
      <% flash.each do |type, message| %>
        <div class="alert alert-<%= type == 'notice' ? 'success' : 'danger' %> alert-dismissible fade show">
          <%= message %>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      <% end %>

      <%= yield %>
    </main>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>
LAYOUT_EOF