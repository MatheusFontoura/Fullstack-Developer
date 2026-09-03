Rails.application.routes.draw do
  resource  :session, only: %i[ new create destroy ]
  resource  :registration, only: %i[ new create ]
  resources :passwords, param: :token, only: %i[ new create edit update ]

  resource :profile, only: %i[ show edit update destroy ]

  namespace :admin do
    resource :dashboard, only: :show

    resources :users, except: :show do
      # The role is a sub-resource rather than a custom action on the user, so that
      # UsersController stays plain CRUD and the "an admin cannot demote themselves"
      # rule has one obvious home.
      resource :role, only: :update, module: :users
    end
  end

  # Returns 200 once the application boots cleanly. Used by the Compose healthcheck
  # and by Kamal to decide when a container is ready to take traffic.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"
end
