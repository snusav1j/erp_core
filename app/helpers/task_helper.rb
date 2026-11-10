module TaskHelper
  def task_status(task)
    return '' unless task

    task_status = task.get_status

    content_tag(:span, class: "status-badge #{task_status[:class]}") do
      concat(ph_icon(task_status[:icon]))
      concat(task_status[:name])
    end
  end

  def task_status_icon(task)
    return '' unless task

    task_status = task.get_status

    content_tag(:span, class: "status-badge status-icon #{task_status[:class]}", data: { tooltip: task_status[:name]}) do
      concat(ph_icon(task_status[:icon]))
    end
  end

  def task_status_text(status)
    return '' unless status.present?

    I18n.t("activerecord.attributes.task.statuses.#{status}").downcase
  end

  def task_status_badge(status)
    return '' unless status.present?

    config = Task::STATUS_CONFIG[status.to_sym]
    return '' unless config

    content_tag(:span, class: "status-badge #{config[:class]}") do
      concat(ph_icon(config[:icon]))
      concat(I18n.t("activerecord.attributes.task.statuses.#{status}"))
    end
  end

  def task_priority(task)
    return '' unless task

    task_priority = task.get_priority

    content_tag(:span, class: "status-badge #{task_priority[:class]}") do
      concat(ph_icon(task_priority[:icon]))
      concat(task_priority[:name])
    end
  end

  def task_priority_icon(task)
    return '' unless task

    task_priority = task.get_priority

    content_tag(:span, class: "status-badge status-icon #{task_priority[:class]}", data: { tooltip: task_priority[:name]}) do
      concat(ph_icon(task_priority[:icon]))
    end
  end

  def task_priority_text(task)
    return '' unless task

    task_priority = task.get_priority

    content_tag(:span, class: "status-badge #{task_priority[:class]}") do
      concat(task.priority_name.downcase)
    end
  end
end