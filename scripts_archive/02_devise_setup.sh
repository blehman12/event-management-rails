#!/bin/bash
set -e
APP_NAME="${1:-ptc_windchill_event}"
echo "Step 2: Setting up Devise authentication"

cd "$APP_NAME"
rails generate devise:install
rails generate devise User
rails generate devise:views
rails generate simple_form:install --bootstrap

USER_MIGRATION=$(find db/migrate -name "*devise_create_users.rb" | head -1)
cat > "$USER_MIGRATION" << 'EOF'
class DeviseCreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :first_name,         null: false
      t.string :last_name,          null: false
      t.string :phone
      t.string :company
      t.boolean :text_capable,      default: false
      t.integer :role,              default: 0
      t.integer :rsvp_status,       default: 0
      t.datetime :invited_at
      t.datetime :registered_at
      t.boolean :calendar_exported, default: false
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps null: false
    end
    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
  end
end
EOF

# CRITICAL FIX: Create custom Devise registration view with all required fields
cat > app/views/devise/registrations/new.html.erb << 'EOF'
<div class="row justify-content-center">
  <div class="col-md-6">
    <div class="card">
      <div class="card-header">
        <h3>Sign up for PTC Windchill Event</h3>
      </div>
      <div class="card-body">
        <%= form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>
          <%= render "devise/shared/error_messages", resource: resource %>

          <div class="row">
            <div class="col-md-6 mb-3">
              <%= f.label :first_name, class: "form-label" %>
              <%= f.text_field :first_name, autofocus: true, class: "form-control", required: true %>
            </div>
            <div class="col-md-6 mb-3">
              <%= f.label :last_name, class: "form-label" %>
              <%= f.text_field :last_name, class: "form-control", required: true %>
            </div>
          </div>

          <div class="mb-3">
            <%= f.label :email, class: "form-label" %>
            <%= f.email_field :email, autocomplete: "email", class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= f.label :phone, class: "form-label" %>
            <%= f.telephone_field :phone, class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= f.label :company, class: "form-label" %>
            <%= f.text_field :company, class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= f.label :password, class: "form-label" %>
            <% if @minimum_password_length %>
            <em>(<%= @minimum_password_length %> characters minimum)</em>
            <% end %>
            <%= f.password_field :password, autocomplete: "new-password", class: "form-control", required: true %>
          </div>

          <div class="mb-3">
            <%= f.label :password_confirmation, class: "form-label" %>
            <%= f.password_field :password_confirmation, autocomplete: "new-password", class: "form-control", required: true %>
          </div>

          <div class="mb-3 form-check">
            <%= f.check_box :text_capable, class: "form-check-input" %>
            <%= f.label :text_capable, "I am okay with receiving text messages", class: "form-check-label" %>
          </div>

          <div class="d-grid">
            <%= f.submit "Sign up", class: "btn btn-primary" %>
          </div>
        <% end %>

        <div class="text-center mt-3">
          <%= render "devise/shared/links" %>
        </div>
      </div>
    </div>
  </div>
</div>
EOF

echo "✓ Devise authentication setup completed with custom registration"
