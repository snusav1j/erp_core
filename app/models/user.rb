class User < ApplicationRecord
  # has_paper_trail(
  #   on: [:create, :update, :destroy],
  #   save_changes: true,
  #   ignore: [
  #     :created_at,
  #     :updated_at,
  #     :last_seen_at,
  #     :sign_in_count,
  #     :current_sign_in_at,
  #     :last_sign_in_at,
  #     :current_sign_in_ip,
  #     :last_sign_in_ip,
  #     :comment,
  #     :reset_password_token,
  #     :encrypted_password,
  #     :remember_created_at,
  #     :reset_password_sent_at,
  #     :sign_in_count,
  #     :current_sign_in_at,
  #     :last_sign_in_at,
  #     :current_sign_in_ip,
  #     :last_seen_at
  #   ]
  # )
  
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable

  has_many :clients, foreign_key: :manager_id
  has_many :orders, foreign_key: :manager_id
  has_many :interactions, foreign_key: :manager_id
  has_many :document_template_versions, foreign_key: :manager_id, dependent: :nullify

  has_many :task_assignees, dependent: :destroy
  has_many :tasks, through: :task_assignees

  has_one :user_setting, dependent: :destroy
  has_one_attached :user_image

  belongs_to :role, optional: true

  scope :active, -> { where.not(banned: true) }


  def active_tasks_count
    self.tasks.where.not(status: [:completed, :cancelled, :draft]).count
  end

  def initials
    "#{self.last_name&.[](0)&.upcase}#{self.first_name&.[](0)&.upcase}"
  end

  def banned?
    self.banned == true
  end

  def owner?
    self.system_role == 'owner'
  end

  def set_sidebar_state(state)
    (self.user_setting || self.create_user_setting).update(hide_sidebar: state)
  end

  def get_sidebar_state
    self.user_setting&.hide_sidebar
  end

  def set_column_visibility_block_state(state)
    (self.user_setting || self.create_user_setting).update(column_visibility_block_state: state)
  end

  def get_column_visibility_block_state
    self.user_setting&.column_visibility_block_state
  end

  def set_custom_fields_block_state(state)
    (self.user_setting || self.create_user_setting).update(custom_fields_block_state: state)
  end

  def get_custom_fields_block_state
    self.user_setting&.custom_fields_block_state
  end

  def fullname
    if self.last_name.present? && self.first_name.present? && self.middle_name.present?
      "#{self.last_name} #{self.first_name} #{self.middle_name}"
    elsif self.last_name.present? && self.first_name.present?
      "#{self.last_name} #{self.first_name}"
    else
      self.email
    end
  end

  def shortname
    if self.last_name.present? && self.first_name.present?
      "#{self.last_name} #{self.first_name}"
    elsif self.first_name.present?
      "#{self.first_name}"
    else
      self.email
    end
  end

  def name
    self.fullname
  end

  def self.filter_collections
    { }
  end

  def self.filter_ignored_columns
    %w[banned comment phone encrypted_password reset_password_token reset_password_sent_at reset_password_created_at remember_created_at created_at updated_at current_sign_in_ip current_sign_in_at last_seen_at sign_in_count last_sign_in_ip last_sign_in_at first_name middle_name telegram_chat_id birthday]
  end

  def self.order_for_filter_columns
    %w[id role last_name email role telegram]
  end
end