Rails.application.routes.draw do
  devise_for :users
  root 'dashboard#index'

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
    end
  end

  get 'dashboard', to: 'dashboard#index'
  patch 'rsvp/:status', to: 'rsvp#update', as: :rsvp
end
