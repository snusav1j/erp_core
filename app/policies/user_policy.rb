class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end

  def edit_modal?
    index?
  end

  def new_modal?
    index?
  end

  def search_options?
    index?
  end

  def show?
    true
  end

  def upload_image?
    self.user.owner? || self.user == self.record
  end

  def destroy_image?
    self.user.owner? || self.user == self.record
  end

  def edit?
    self.user == self.record || index?
  end
end