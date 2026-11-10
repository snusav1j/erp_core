class ClientPolicy < ApplicationPolicy
  def index?
    allowed?(:client, :access)
  end

  def show?
    allowed?(:client, :access)
  end

  def search_options?
    true
  end

  def new_modal?
    allowed?(:client, :create)
  end
  
  def create?
    allowed?(:client, :create)
  end
  
  def check_existing_client?
    allowed?(:client, :create)
  end
  
  def check_existing_client_modal?
    check_existing_client?
  end
  
  def edit_modal?
    allowed?(:client, :update)
  end

  def update?
    allowed?(:client, :update)
  end

  def destroy?
    allowed?(:client, :delete)
  end
end