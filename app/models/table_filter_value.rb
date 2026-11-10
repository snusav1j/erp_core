class TableFilterValue < ApplicationRecord
  belongs_to :user

  def self.value(entity:, column_key:, user:)
    self.find_by(entity: entity, column_key: column_key, user: user)&.value
  end

  def self.save_value(entity:, column_key:, value:, user:)
    record = self.find_or_initialize_by(entity: entity, column_key: column_key, user: user)

    record.value = value
    record.save!

    record
  end
end