
class TasksController < ApplicationController
  before_action :get_entity, only: [:index, :show]

  def index
    get_tasks
  end

  def show
    @task = Task.find(params[:id])
  end

  def new_modal
    @task = Task.new
    @task.author = current_user
    @task.status = :draft

    if params[:parent_id].present?
      @parent = Task.tasks.find(params[:parent_id])

      unless @parent.status_draft? || current_user.owner?
        head :unprocessable_entity
        return
      end

      @task.parent_id = @parent.id
      @task.author = @parent.author
    end

    respond_to :js
  end

  def edit_modal
    @task = Task.find(params[:id])

    unless @task.author_id == current_user.id || current_user.owner?
      head :forbidden
      return
    end

    unless @task.status_draft? || @task.status_new? || current_user.owner?
      head :unprocessable_entity
      return
    end

    respond_to :js
  end

  def assignee_modal
    @task = Task.tasks.find(params[:id])

    unless (@task.author_id == current_user.id && @task.status_draft?) || current_user.owner?
      head :unprocessable_entity
      return
    end

    @task_assignee = TaskAssignee.new
    @users = User.all

    respond_to :js
  end

  def subtasks_modal
    @task = Task.tasks.find(params[:id])
    @subtasks = @task.get_subtasks

    respond_to :js
  end

  def create
    @task = Task.new(task_params)
    @task.author = current_user
    @task.status = :draft

    if @task.parent.present?
      @task.author = @task.parent.author

      unless @task.parent.status_draft? || current_user.owner?
        @task.errors.add(:parent, :invalid)
      end
    end

    @created = save_with_toastr(@task)
    get_tasks

    respond_to :js
  end

  def update
    @task = Task.find(params[:id])

    if (@task.author_id == current_user.id && (@task.status_draft? || @task.status_new?)) || current_user.owner?
      @updated = update_with_toastr(@task, task_params)
    else
      @updated = false
    end

    get_tasks

    respond_to :js
  end

  def repeat
    @task = Task.find(params[:id])
    @repeated = false

    begin
      @repeated = @task.repeat!
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def return_to_draft
    @task = Task.find(params[:id])
    @returned_to_draft = false

    begin
      @returned_to_draft = @task.return_to_draft_by!(
        current_user,
        owner: current_user.owner?
      )
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def publish
    @task = Task.tasks.find(params[:id])
    @published = false

    if @task.author_id == current_user.id || current_user.owner?
      begin
        @published = @task.publish!
      rescue ActiveRecord::RecordInvalid => e
        @task = e.record
        flash[:error] = @task.errors.full_messages.join(', ')
      end
    end

    get_tasks

    respond_to :js
  end

  def assign_assignee
    @task = Task.tasks.find(params[:id])

    unless (@task.author_id == current_user.id && @task.status_draft?) || current_user.owner?
      @assigned = false
      respond_to :js
      return
    end

    @task_assignee = @task.task_assignees.new(
      user_id: params[:task_assignee][:user_id]
    )

    @assigned = save_with_toastr(@task_assignee)
    get_tasks

    respond_to :js
  end

  def destroy
    @task = Task.find(params[:id])

    if (@task.author_id == current_user.id && (@task.status_draft? || @task.status_completed? || @task.status_cancelled?)) || current_user.owner?
      @destroyed = destroy_with_toastr(@task)
    else
      @destroyed = false
    end

    get_tasks

    respond_to :js
  end

  def start
    @task = Task.find(params[:id])
    @started = false

    begin
      @started = @task.start_by!(current_user, owner: current_user.owner?)
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def complete
    @task = Task.find(params[:id])
    @completed = false

    begin
      @completed = @task.complete_by!(current_user, owner: current_user.owner?)
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def return_to_work
    @task = Task.find(params[:id])
    @returned = false

    begin
      @returned = @task.return_to_work!(current_user, owner: current_user.owner?)
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def cancel
    @task = Task.find(params[:id])
    @cancelled = false

    begin
      @cancelled = @task.cancel_by!(current_user, owner: current_user.owner?)
    rescue ActiveRecord::RecordInvalid => e
      @task = e.record
      flash[:error] = @task.errors.full_messages.join(', ')
    end

    get_tasks

    respond_to :js
  end

  def search_options
    tasks = Task.active

    if params[:q].present?
      tasks = tasks.smart_search(
        column: [:task_title, :description],
        query: params[:q]
      )
    end

    render json: {
      collection: tasks.map { |task|
        priority = task.get_priority

        {
          key: task.id,
          value: task.task_title,
          class: priority[:class],
          icon: {
            icon_title: priority[:name],
            icon_class: priority[:icon_class]
          }
        }
      }
    }
  end

  def destroy_assignee
    @task = Task.tasks.find(params[:id])

    unless (@task.author_id == current_user.id && @task.status_draft?) || current_user.owner?
      @destroyed = false
      respond_to :js
      return
    end

    @task_assignee = @task.task_assignees.find_by!(
      user_id: params[:user_id]
    )

    @destroyed = destroy_with_toastr(@task_assignee)

    respond_to :js
  end

  private

  def get_entity
    @entity = "Task"
  end

  def get_tasks
    @tasks = if current_user.owner?
      Task.tasks
    else
      Task.tasks
        .left_joins(:task_assignees)
        .where(
          "tasks.author_id = :user_id OR (tasks.status != :draft AND task_assignees.user_id = :user_id)",
          draft: Task.statuses[:draft],
          user_id: current_user.id
        )
        .distinct
    end

    @tasks_by_status = Task.grouped_by_status(@tasks)
  end

  def task_params
    params.require(:task).permit(
      :parent_id,
      :task_title,
      :description,
      :priority,
      :requires_review,
      :start_at,
      :deadline
    )
  end
end
