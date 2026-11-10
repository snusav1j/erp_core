
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:edit, :update]
  before_action :authorize_action, except: [:show, :upload_image, :destroy_image]

  before_action :get_entity, only: [:index]

  def index
    get_users
  end

  def show
    @user = User.find(params[:id])
  end

  def edit
    @user = User.find(params[:id])
  end

  def new_modal
    @user = User.new
    respond_to :js
  end

  def edit_modal
    @user = User.find(params[:id])
    respond_to :js
  end

  def create
    @user = User.new(user_params)
    @user.system_role = 'user'
    @created = save_with_toastr(@user)

    @users = get_users if @created
    respond_to :js
  end

  def update
    @user = User.find(params[:id])
    @updated = update_with_toastr(@user, user_params)

    @users = get_users if @updated
    respond_to :js
  end

  def destroy
    @user = User.find(params[:id])
    @destroyed = destroy_with_toastr(@user)

    @users = get_users if @destroyed
    respond_to :js
  end

  def search_options
    users = User.all

    if params[:q].present?
      users = users.smart_search(column: [:middle_name, :last_name, :first_name, :email, :telegram], query: params[:q])
    end

    render json: {
      collection: users.map { |user|
        {
          key: user.id,
          value: "#{user.shortname} <span class='user-role text-small text-muted'>#{user.role&.name}</span>",
          description: user.email,
          icon: {
            icon_url: user.user_image.attached? ? url_for(user.user_image) : nil,
            icon_class: 'user-image-option user-icon',
            icon_text: user.user_image.attached? ? nil : user.initials
          }
        }
      }
    }
  end

  def upload_image
    @user = User.find(params[:id])
    authorize @user

    @user.user_image.attach(params[:user_image])

    respond_to do |format|
      format.js
    end
  end

  def destroy_image
    @user = User.find(params[:id])
    authorize @user

    @user.user_image.purge

    respond_to do |format|
      format.js
    end
  end

  private

  def get_entity
    @entity = 'User'
  end

  def get_users
    @filters = params[:filters]&.to_unsafe_h || {}

    @users = User.filter(@filters, current_user, page: params[:page]).reorder(id: :asc)
  end

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_action
    authorize @user || User
  end

  def user_params
    params.require(:user).permit(
      :email,
      :last_name,
      :first_name,
      :middle_name,
      :phone,
      :birthday,
      :telegram,
      :telegram_chat_id,
      :password,
      :password_confirmation,
      :role_id,
      :banned
    )
  end
end
