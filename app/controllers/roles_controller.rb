class RolesController < ApplicationController

  def index
    @roles = Role.all
  end

  def show
    @role = Role.find(params[:id])
  end

  def new_modal
    @role = Role.new
    respond_to :js
  end

  def edit_modal
    @role = Role.find(params[:id])
    respond_to :js
  end

  def permissions
    @role = Role.find(params[:id])

    permissions = @role.permissions.deep_dup
    permissions[params[:entity]] ||= {}
    permissions[params[:entity]][params[:permission]] = params[:value] == 'true'

    @role.update!(permissions: permissions)

    respond_to :js
  end

  def create
    @role = Role.new(role_params)
    @created = save_with_toastr(@role)

    @roles = Role if @created
    respond_to :js
  end

  def update
    @role = Role.find(params[:id])
    @updated = update_with_toastr(@role, role_params)

    @roles = Role if @updated
    respond_to :js
  end

  def destroy
    @role = Role.find(params[:id])
    @destroyed = destroy_with_toastr(@role)

    @roles = Role if @destroyed
    respond_to :js
  end

  private

  def role_params
    params.require(:role).permit(:name)
  end

end