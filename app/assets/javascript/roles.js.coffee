$(document).on 'change', '.role-permission-toggle', ->

  input = $(this)

  role_id = $('#role-permissions-form').data('role-id')

  entity = input.data('entity')

  permission = input.data('permission')

  value = input.is(':checked')

  if permission == 'access'
    section = input.closest('.role-permissions-section')
    section.find('.role-permission-toggle').not(input).prop('disabled', !value)

  $.ajax
    url: "/roles/#{role_id}/permissions"
    method: 'PATCH'
    data:
      entity: entity
      permission: permission
      value: value