class RolePermissions
  CLIENT = %i[
    access
    create
    update
    delete
  ].freeze

  def self.all
    {
      client: CLIENT
    }
  end

  def self.for(entity)
    const_get(entity.to_s&.upcase)
  end

  def self.allowed?(entity, permission)
    self.for(entity).include?(permission.to_sym)
  end
end