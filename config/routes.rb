Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors and load balancers.
  get "up" => "rails/health#show", as: :rails_health_check

  # Devise routes for user authentication
  devise_for :users

  # Root route
  root 'dashboard#index'

  # Public dashboard
  get 'dashboard', to: 'dashboard#index'

  # User profile and settings
  get 'profile', to: 'users#show'
  get 'profile/edit', to: 'users#edit'
  patch 'profile', to: 'users#update'

  # RSVP routes
  get 'rsvp/:event_id', to: 'rsvp#show', as: 'event_rsvp'
  patch 'rsvp/:event_id', to: 'rsvp#update', as: 'update_rsvp'

  # Check-in routes (public - no authentication required for basic access)
  get 'checkin', to: 'checkin#index'
  get 'checkin/scan', to: 'checkin#scan'
  get 'checkin/manual', to: 'checkin#manual'
  post 'checkin/verify', to: 'checkin#verify'
  get 'checkin/success/:id', to: 'checkin#success', as: 'checkin_success'

  # Calendar routes
  get 'calendar/:event_id', to: 'calendar#show', as: 'event_calendar'
  get 'calendar/:event_id/export', to: 'calendar#export', as: 'export_event_calendar'

  # Admin routes - protected by authentication and admin role
  namespace :admin do
    # Redirect old destroy URLs to the proper show page
    get 'users/:id/destroy', to: redirect('/admin/users/%{id}')
    
    # REDIRECT old bulk actions to new dedicated interface
    get 'users/bulk_actions', to: redirect('/admin/bulk_users')
    
    # Admin dashboard
    get 'dashboard', to: 'dashboard#index'
    root 'dashboard#index'

    # User management
    resources :users do
      member do
        patch 'toggle_admin'
        delete 'destroy'
      end
      collection do
        # OLD bulk actions route is now redirected above
        # get 'bulk_actions'  # <- This is now redirected to /admin/bulk_users
        post 'bulk_create'
        post 'bulk_invite'
        post 'bulk_delete'
        get 'export'
        post 'import'
      end
    end

    # NEW Dedicated Bulk User Management Interface
    resources :bulk_users, only: [:index] do
      collection do
        get :import_form
        post :process_import
        post :bulk_actions         # This matches your form URL
        get :export_csv
      end
    end

  # Event management
resources :events do
  member do
    get :participants
    post :add_participant
    patch :update_participant_role
    delete :remove_participant
    get :export_participants
    post :bulk_invite_participants
  end
  collection do
    get :bulk_actions
    post :bulk_activate
    post :bulk_deactivate
    post :bulk_delete
    get :export
  end
end

    # Venue management
    resources :venues do
      collection do
        get 'bulk_actions'
        post 'bulk_delete'
        post 'bulk_archive'
        get 'export'
        post 'import'
      end
    end

    # Email management
    resources :email_campaigns, only: [:new, :create, :index, :show] do
      member do
        get 'preview'
        post 'send_test'
      end
    end

    # Check-in management
    get 'checkin', to: 'checkin#index'
    get 'checkin/dashboard', to: 'checkin#dashboard'
    get 'checkin/dashboard/:event_id', to: 'checkin#event_dashboard', as: 'event_checkin_dashboard'
    post 'checkin/bulk', to: 'checkin#bulk_checkin'
    get 'checkin/export/:event_id', to: 'checkin#export', as: 'export_checkin'
    get 'checkin/qr_codes/:event_id', to: 'checkin#qr_codes', as: 'event_qr_codes'
    get 'checkin/print_badges/:event_id', to: 'checkin#print_badges', as: 'print_badges'
    
    # Reports and analytics
    get 'reports', to: 'reports#index'
    get 'reports/events', to: 'reports#events'
    get 'reports/attendance', to: 'reports#attendance'
    get 'reports/users', to: 'reports#users'
    get 'reports/export/:type', to: 'reports#export', as: 'export_report'
  end

  # API routes (if needed for mobile apps or AJAX)
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/login', to: 'authentication#login'
      post 'auth/logout', to: 'authentication#logout'
      
      # Events
      resources :events, only: [:index, :show] do
        member do
          post 'rsvp'
          get 'participants'
        end
      end
      
      # Check-ins
      post 'checkins', to: 'checkins#create'
      get 'checkins/verify', to: 'checkins#verify'
      
      # User profile
      get 'profile', to: 'users#show'
      patch 'profile', to: 'users#update'
    end
  end

  # Legacy routes for backwards compatibility (if needed)
  get '/events/:id/rsvp', to: redirect('/rsvp/%{id}')
  get '/admin/events/:id/checkin', to: redirect('/admin/checkin/dashboard/%{id}')

  # Error pages
  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable_entity'
  get '/500', to: 'errors#internal_server_error'
end