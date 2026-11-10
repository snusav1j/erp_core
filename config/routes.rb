Rails.application.routes.draw do
  devise_for :users,
             path: "",
             skip: [:registrations, :confirmations, :unlocks],
             path_names: {
               sign_in: 'login',
               sign_out: 'logout'
             }

  root 'application#root'

  get "redirect_to_previous_page", to: "application#redirect_to_previous_page"
  get "versions/modal", to: "versions#modal", as: :versions_modal
  
  resources :versions, only: [] do
    member do
      get :changeset
    end
  end


    
  resources :tasks do
    collection do
      get :new_modal
      get :edit_modal
      get :search_options
    end

    member do
      get :assignee_modal
      get :subtasks_modal
      post :assign_assignee
      delete :destroy_assignee
      post :publish
      post :start
      post :complete
      post :return_to_work
      post :return_to_draft
      post :repeat
      post :cancel
    end
  end

  resources :users, only: [:index, :new, :create, :edit, :update, :destroy, :show] do
    collection do
      get :new_modal
      get :edit_modal
      get :search_options
    end

    member do
      patch :upload_image
      delete :destroy_image
    end
  end
  
  resources :user_settings do
    collection do
      post :set_sidebar_state
      post :set_column_visibility_block_state
      post :set_custom_fields_table_block_state
      post :update_table_per_page
    end
  end



  resources :roles do
    collection do
      get :new_modal
      get :edit_modal
    end
    member do
      patch :permissions
    end
  end

end