Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'

  # RSVP routes
  get 'rsvp', to: 'rsvp#show'
  patch 'rsvp', to: 'rsvp#update', as: :rsvp_update

  # Check-in routes (public interface)
  get 'checkin', to: 'checkin#index'
  get 'checkin/scan', to: 'checkin#scan'
  get 'checkin/manual', to: 'checkin#manual'
  get 'checkin/verify', to: 'checkin#verify'
  post 'checkin/process', to: 'checkin#process_checkin'
  get 'checkin/success/:id', to: 'checkin#success'

  # Admin routes
  namespace :admin do
    resources :bulk_users, only: [:index] do
      collection do
        get :import_form
        post :import_csv
        post :bulk_actions
        get :export_csv
      end
    end
    
    root 'dashboard#index'
    resources :users
    resources :venues
    
    resources :events do
      resources :event_participants, except: [:new, :edit]
      
      # Check-in routes using separate controller
      member do
        get :checkin_dashboard, controller: 'checkin'
        get :generate_qr_codes, controller: 'checkin'
        post :generate_qr_codes, action: :create_qr_codes, controller: 'checkin'
        get :print_badges, controller: 'checkin'
        get :bulk_checkin, controller: 'checkin'
        patch :bulk_checkin, action: :process_bulk_checkin, controller: 'checkin'
        get :export_checkin_data, controller: 'checkin'
        get :dashboard_stats, controller: 'checkin'
      end
    end
  end

  # Dashboard route
  get 'dashboard', to: 'dashboard#index'
end