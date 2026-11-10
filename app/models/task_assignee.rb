class TaskAssignee < ApplicationRecord
  belongs_to :task
  belongs_to :user

  validates :user_id, uniqueness: { scope: :task_id }

  validate :user_same_company

  private

  def user_same_company
    return unless self.task.present? && self.user.present?
    return if self.task.company_id == self.user.company_id

    errors.add(:user, :invalid)
  end
end