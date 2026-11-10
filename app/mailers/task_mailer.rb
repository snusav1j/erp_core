class TaskMailer < ApplicationMailer
  def assigned(task:, user:)
    @task = task
    @user = user
    @tasks_url = tasks_url

    mail(
      to: user.email,
      subject: I18n.t('task_mailer.assigned.subject', title: task.task_title)
    )
  end

  def returned_to_work(task:, user:)
    @task = task
    @user = user
    @tasks_url = tasks_url

    mail(
      to: user.email,
      subject: I18n.t('task_mailer.returned_to_work.subject', title: task.task_title)
    )
  end

  def completed(task:, user:)
    @task = task
    @user = user
    @tasks_url = tasks_url

    mail(
      to: user.email,
      subject: I18n.t('task_mailer.completed.subject', title: task.task_title)
    )
  end
end