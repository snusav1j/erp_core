class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def allowed?(entity, permission)
    return true if user.owner?

    permissions = user.role&.permissions&.dig(entity.to_s)

    return false unless permissions&.dig('access') == true
    return true unless RolePermissions.allowed?(entity, permission)

    permissions&.dig(permission.to_s) == true
  end

  def index?
    false
  end

  def show?
    scope.where(:id => record.id).exists?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end