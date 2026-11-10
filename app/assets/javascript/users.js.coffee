$(document).on 'dblclick', '#users-list tr.user-row', (e) ->
  user_id = $(this).attr('data-user-id')

  $.ajax
    url: "/users/edit_modal"
    type: 'GET'
    dataType: 'script'
    data:
      id: user_id

$(document).on 'change', '.table-per-page', ->
  select = $(this)
  entity = select.data('entity')
  per_page = select.val()

  box_header = $(".content-box-header[data-entity='#{entity}']")
  box_header.find('.content-box-header-loader').show()
  box_header.find('.content-box-header-length').hide()

  select.addClass('disabled')

  $.ajax
    url: '/user_settings/update_table_per_page'
    async: true
    type: 'POST'
    dataType: 'script'
    data:
      entity: entity
      per_page: per_page
    success: ->
      $.ajax
        url: window.location.pathname
        async: true
        dataType: 'script'
        success: ->
          select.removeClass('disabled')


$(document).on 'change', '#imageUpload', ->
  input = $(this)
  return unless input[0].files[0]

  form_data = new FormData()
  form_data.append('user_image', input[0].files[0])
  form_data.append('authenticity_token', $('meta[name="csrf-token"]').attr('content'))

  $.ajax
    url: "/users/#{input.data('user-id')}/upload_image"
    method: 'PATCH'
    data: form_data
    processData: false
    contentType: false
    dataType: 'script'