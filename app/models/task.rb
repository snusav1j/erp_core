
class Task < ApplicationRecord
  belongs_to :parent, class_name: 'Task', optional: true
  belongs_to :author, class_name: 'User'

  has_many :subtasks, class_name: 'Task', foreign_key: :parent_id, dependent: :destroy

  has_many :task_assignees, dependent: :destroy
  has_many :assignees, through: :task_assignees, source: :user

  has_many_attached :files

  enum :status, {
    draft: 0,
    new: 1,
    in_progress: 2,
    completed: 3,
    cancelled: 4
  }, prefix: true

  enum :priority, {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3
  }, prefix: true

  validates :task_title, presence: true
  validates :status, presence: true
  validates :priority, presence: true
  validates :deadline, presence: true

  validate :parent_cannot_be_subtask

  before_validation :set_parent_attributes
  after_update :update_subtasks_attributes, if: :priority_or_deadline_changed?

  scope :tasks, -> { where(parent_id: nil) }
  scope :subtasks, -> { where.not(parent_id: nil) }
  scope :active, -> { where.not(status: [:completed, :cancelled]) }

  STATUS_CONFIG = {
    draft: { class: 'color-badge-default', icon: :file_dashed },
    new: { class: 'color-badge-primary', icon: :hourglass },
    in_progress: { class: 'color-badge-info spin-icon', icon: :spinner },
    completed: { class: 'color-badge-success', icon: :checks },
    cancelled: { class: 'color-badge-danger', icon: :prohibit }
  }.freeze

  PRIORITY_CONFIG = {
    low: { class: 'color-badge-default', icon: :leaf },
    normal: { class: 'color-badge-primary-light', icon: :briefcase },
    high: { class: 'color-badge-warning', icon: :seal_warning },
    urgent: { class: 'color-badge-danger', icon: :siren }
  }.freeze

  STATUS_SORT_ORDER = {
    'in_progress' => 0,
    'new' => 1,
    'draft' => 2,
    'completed' => 3,
    'cancelled' => 4
  }.freeze

  def self.status_collection
    STATUS_CONFIG.map do |status, config|
      [
        I18n.t("activerecord.attributes.task.statuses.#{status}"),
        status.to_s,
        {
          'data-class' => config[:class],
          'data-icon-class' => "ph ph-#{config[:icon].to_s.tr('_', '-')}"
        }
      ]
    end
  end

  def self.priority_collection
    PRIORITY_CONFIG.map do |priority, config|
      [
        I18n.t("activerecord.attributes.task.priorities.#{priority}"),
        priority.to_s,
        {
          'data-class' => config[:class],
          'data-icon-class' => "ph ph-#{config[:icon].to_s.tr('_', '-')}"
        }
      ]
    end
  end

  def self.filter_collections
    {
      author_id: User.all,
      assignee_id: User.all,
      parent_id: Task.tasks,
      status: self.status_collection,
      priority: self.priority_collection
    }
  end

  def self.sorted_list(relation)
    relation.sort_by { |task| task.sort_key }
  end

  def self.grouped_by_status(relation)
    grouped = relation.group_by(&:status).transform_values do |list|
      list.sort_by { |task| task.sort_key_within_status }
    end

    STATUS_SORT_ORDER.keys.each_with_object({}) do |status, hash|
      hash[status] = grouped[status] if grouped[status].present?
    end
  end

  def get_subtasks
    self.class.sorted_list(self.subtasks)
  end

  def sort_key
    [
      STATUS_SORT_ORDER[self.status.to_s] || 99,
      *self.sort_key_within_status
    ]
  end

  def sort_key_within_status
    priority = -self.read_attribute_before_type_cast('priority').to_i

    if self.status.in?(%w[completed cancelled])
      [priority, -(self.completed_at || Time.at(0)).to_i]
    else
      [priority, self.deadline || Time.zone.parse('9999-12-31')]
    end
  end

  def status_name
    I18n.t("activerecord.attributes.task.statuses.#{self.status}")
  end

  def priority_name
    I18n.t("activerecord.attributes.task.priorities.#{self.priority}")
  end

  def get_status
    return '' unless self.status.present?

    config = STATUS_CONFIG[self.status.to_sym]
    return '' unless config

    {
      name: I18n.t("activerecord.attributes.task.statuses.#{self.status}"),
      class: config[:class],
      icon: config[:icon],
      icon_class: "ph ph-#{config[:icon].to_s.tr('_', '-')}"
    }
  end

  def get_priority
    return '' unless self.priority.present?

    config = PRIORITY_CONFIG[self.priority.to_sym]
    return '' unless config

    {
      name: I18n.t("activerecord.attributes.task.priorities.#{self.priority}"),
      class: config[:class],
      icon: config[:icon],
      icon_class: "ph ph-#{config[:icon].to_s.tr('_', '-')}"
    }
  end

  def overdue?
    self.deadline.present? && self.deadline < Time.current && !self.status_completed? && !self.status_cancelled?
  end

  def subtasks_count
    self.subtasks.count
  end

  def completed_subtasks_count
    self.subtasks.status_completed.count
  end

  def progress_percent
    return 100 if self.status_completed?
    return 0 unless self.has_subtasks?

    (self.completed_subtasks_count.to_f / self.subtasks_count * 100).round
  end

  def subtask_progress
    "#{self.completed_subtasks_count}/#{self.subtasks_count}"
  end

  def has_subtasks?
    self.subtasks.exists?
  end

  def work_duration
    return self.subtasks.sum(:work_duration).to_f if self.has_subtasks?

    self.own_work_duration
  end

  def assignees_for_task
    self.parent.present? ? self.parent.assignees : self.assignees
  end

  def repeat!
    return false unless self.status_cancelled? || self.status_completed? || self.status_draft?

    transaction do
      repeated_task = self.class.new(
        author: self.author,
        parent: nil,
        task_title: self.task_title,
        description: self.description,
        priority: self.priority,
        requires_review: self.requires_review,
        deadline: self.deadline,
        status: :draft
      )

      repeated_task.save!

      self.task_assignees.each do |task_assignee|
        repeated_task.task_assignees.create!(
          user_id: task_assignee.user_id
        )
      end

      if self.parent.nil? && self.has_subtasks?
        self.subtasks.each do |subtask|
          repeated_subtask = repeated_task.subtasks.new(
            author: subtask.author,
            task_title: subtask.task_title,
            description: subtask.description,
            priority: subtask.priority,
            requires_review: subtask.requires_review,
            deadline: repeated_task.deadline,
            status: :draft
          )

          repeated_subtask.save!

          subtask.task_assignees.each do |task_assignee|
            repeated_subtask.task_assignees.create!(
              user_id: task_assignee.user_id
            )
          end
        end
      end
    end

    true
  end

  def publish!
    return false unless self.status_draft?

    if self.assignees.empty?
      self.errors.add(
        :base,
        I18n.t('model_errors.task.no_assignees')
      )
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      self.update!(status: :new)

      self.subtasks.update_all(
        status: Task.statuses[:new],
        updated_at: Time.current
      )
    end

    self.assignees.find_each do |user|
      next if user.email.blank?

      # TaskMailer.assigned(task: self, user: user).deliver_now
    end

    true
  end

  def return_to_draft_by!(user, owner: false)
    return false unless owner || self.author_id == user.id
    return false unless self.status_new?
    return false if self.start_at.present?

    if self.parent.nil? && self.has_subtasks?
      return false unless self.subtasks.status_new.where(start_at: nil).count == self.subtasks.count
    end

    transaction do
      self.update!(
        status: :draft,
        start_at: nil,
        completed_at: nil,
        reviewed_at: nil
      )

      if self.parent.nil? && self.has_subtasks?
        self.subtasks.update_all(
          status: Task.statuses[:draft],
          start_at: nil,
          completed_at: nil,
          reviewed_at: nil,
          updated_at: Time.current
        )
      end
    end

    true
  end

  def start_by!(user, owner: false)
    return false unless owner || self.assignees_for_task.exists?(id: user.id)
    return false unless self.status_new?

    transaction do
      self.update!(
        status: :in_progress,
        start_at: Time.current,
        completed_at: nil
      )

      if self.parent.nil? && self.has_subtasks?
        self.subtasks.update_all(
          status: Task.statuses[:in_progress],
          start_at: Time.current,
          completed_at: nil,
          reviewed_at: nil,
          updated_at: Time.current
        )
      elsif self.parent.present?
        self.parent.update!(
          status: :in_progress,
          start_at: self.parent.start_at || Time.current,
          completed_at: nil
        )
      end
    end

    true
  end

  def complete_by!(user, owner: false)
    return false unless owner || self.assignees_for_task.exists?(id: user.id)
    return false unless self.status_in_progress?
    return false if self.has_subtasks?

    transaction do
      completed_at = Time.current
      duration = completed_at - self.start_at

      self.update!(
        status: :completed,
        completed_at: completed_at,
        work_duration: self.own_work_duration + duration
      )

      complete_parent_if_all_subtasks_completed
    end

    if self.parent.blank?
      notify_completed!(self)
    end

    true
  end

  def return_to_work!(user, owner: false)
    return false unless owner || self.author_id == user.id
    return false unless self.status_completed?

    parent_was_completed = self.parent.present? && self.parent.status_completed?

    transaction do
      new_deadline = deadline_after_return_to_work

      self.update!(
        status: :in_progress,
        start_at: Time.current,
        completed_at: nil,
        deadline: new_deadline
      )

      if self.parent.present?
        parent_deadline = parent_deadline_after_return_to_work

        self.parent.update!(
          status: :in_progress,
          start_at: self.parent.start_at || Time.current,
          completed_at: nil,
          deadline: parent_deadline
        )

        self.update!(deadline: self.parent.deadline)
      elsif self.has_subtasks?
        self.subtasks.where(status: :completed).find_each do |subtask|
          subtask.update!(
            status: :in_progress,
            start_at: Time.current,
            completed_at: nil,
            deadline: self.deadline,
            updated_at: Time.current
          )
        end
      end
    end

    if self.parent.blank?
      notify_returned_to_work!(self)
    elsif parent_was_completed
      notify_returned_to_work!(self.parent)
    end

    true
  end

  def cancel_by!(user, owner: false)
    return false unless owner || self.author_id == user.id
    return false if self.status_cancelled?

    transaction do
      self.update!(
        status: :cancelled,
        completed_at: nil
      )

      if self.parent.nil?
        self.subtasks.update_all(
          status: Task.statuses[:cancelled],
          completed_at: nil,
          updated_at: Time.current
        )
      end
    end

    true
  end

  private

  def own_work_duration
    self[:work_duration].to_f
  end

  def notify_completed!(task)
    return unless task.author.present? && task.author.email.present?

    # TaskMailer.completed(task: task, user: task.author).deliver_now
  end

  def notify_returned_to_work!(task)
    task.assignees_for_task.find_each do |assignee|
      next if assignee.email.blank?

      # TaskMailer.returned_to_work(task: task, user: assignee).deliver_now
    end
  end

  def deadline_after_return_to_work
    if self.deadline.present? && Date.current < self.deadline.to_date
      return self.deadline
    end

    duration = self.work_duration.to_f
    Time.current + (duration.positive? ? duration + 1.hour : 1.hour)
  end

  def parent_deadline_after_return_to_work
    parent = self.parent
    return parent.deadline if parent.deadline.present? && Date.current < parent.deadline.to_date

    duration = parent.work_duration.to_f
    Time.current + (duration.positive? ? duration + 1.hour : 1.hour)
  end

  def set_parent_attributes
    return unless self.parent.present?

    self.priority = self.parent.priority
    self.deadline = self.parent.deadline
  end

  def priority_or_deadline_changed?
    self.saved_change_to_priority? || self.saved_change_to_deadline?
  end

  def update_subtasks_attributes
    return unless self.parent_id.nil?
    return unless self.priority_or_deadline_changed?

    self.subtasks.update_all(
      priority: self.priority,
      deadline: self.deadline,
      updated_at: Time.current
    )
  end

  def complete_parent_if_all_subtasks_completed
    return unless self.parent.present?

    parent = self.parent

    return unless parent.subtasks.exists?
    return unless parent.subtasks.where.not(status: :completed).none?

    parent.update!(
      status: :completed,
      completed_at: Time.current
    )

    notify_completed!(parent)
  end

  def parent_deadline_after_return
    return self.parent.deadline unless self.parent.deadline.present?

    duration = self.parent.work_duration
    return self.parent.deadline unless duration.positive?

    Time.current + duration
  end

  def parent_cannot_be_subtask
    return unless self.parent.present?
    return unless self.parent.parent_id.present?

    errors.add(:parent, :invalid)
  end
end
