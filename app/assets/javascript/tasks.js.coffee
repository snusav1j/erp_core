$(document).on 'dblclick', '#tasks-list tr.task-row', (e) ->
  task_id = $(this).attr('data-task-id')

  $.ajax
    url: "/tasks/edit_modal"
    type: 'GET'
    dataType: 'script'
    data:
      id: task_id