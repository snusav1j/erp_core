class UserSettingsController < ApplicationController

  def index

  end

  def show

  end

  def update_table_per_page
    entity_class = params[:entity].to_s.safe_constantize
    per_page = params[:per_page].to_i

    unless entity_class && entity_class < ApplicationRecord &&
        ApplicationRecord::PER_PAGE_COLLECTION.include?(per_page)
      return head :unprocessable_entity
    end

    user_setting = current_user.user_setting || current_user.create_user_setting
    user_setting.set_table_per_page(entity_class.name, per_page)

    respond_to :js
  end
  
  def set_sidebar_state
    @updated = current_user.set_sidebar_state(param_b(:sidebar_hidden))
    respond_to :js
  end

  def set_column_visibility_block_state
    @updated = current_user.set_column_visibility_block_state(param_b(:block_hidden))
    respond_to :js
  end

  def set_custom_fields_table_block_state
    @updated = current_user.set_custom_fields_block_state(param_b(:block_hidden))
    respond_to :js
  end
  
  private

end