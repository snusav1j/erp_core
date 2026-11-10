class Users::SessionsController < Devise::SessionsController

  def create
    self.resource = warden.authenticate(auth_options)

    if resource
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      flash.now[:danger] = { description: t('devise.failure.invalid') }
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      respond_with resource, action: :new
    end
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end

end