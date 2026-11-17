Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :books, only: %i[index show create destroy], param: :serial_number do
        resource :status, only: :update, controller: "book_statuses"
      end
      resources :readers, only: %i[index show create], param: :card_number
    end
  end
end
