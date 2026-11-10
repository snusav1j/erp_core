$.rails.allowAction = (link) ->
  return true unless link.attr('data-confirm')

  $.rails.showConfirmDialog(link)
  false


$.rails.confirmed = (link) ->
  link.removeAttr('data-confirm')
  link.trigger('click.rails')


$.rails.showConfirmDialog = (link) ->

  modal = $('#confirm-alert-modal')

  modal.find('.confirmation-message').text(link.attr('data-confirm'))

  modal.find('.confirm')
    .off('click')
    .on 'click', ->

      modal.modal('hide')

      $.rails.confirmed(link)

  modal.modal('show')
  modal.find('.confirm').focus()