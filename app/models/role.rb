class Role < ApplicationRecord
  # has_paper_trail(
  #   on: [:create, :update, :destroy],
  #   save_changes: true,
  #   ignore: [
  #     :created_at,
  #     :updated_at,
  #     :comment
  #   ]
  # )

  has_many :users, dependent: :nullify

  validates :name, presence: true, uniqueness: true
end
