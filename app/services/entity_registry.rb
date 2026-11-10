class EntityRegistry
  MODELS = {
    "Role" => Role,
    "Task" => Task,
    "User" => User,
  }.freeze

  def self.get(entity)
    MODELS[entity]
  end
end