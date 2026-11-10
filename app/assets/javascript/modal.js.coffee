jQuery.fn.modal = (action) ->
  return this unless @length

  $modal = @first()

  switch action
    when 'show'
      $modal.addClass('show')
      $('body').addClass('modal-open')
      $modal.css(display: 'block', opacity: 0)
      $modal.find('.modal-dialog').css(transform: 'translateY(-30px)')

      setTimeout ->
        $modal.css(opacity: 1)
        $modal.find('.modal-dialog').css(transform: 'translateY(0)')
      , 10

      $modal.trigger('shown.modal')

    when 'hide'
      $modal.css(opacity: 0)
      $modal.find('.modal-dialog').css(transform: 'translateY(-30px)')

      setTimeout =>
        $modal.removeClass('show').css(display: 'none')
        if !$('.modal.show').length
          $('body').removeClass('modal-open')
        $modal.trigger('hidden.modal')
      , 350

  this

$ ->

  $(document).on 'click', '.modal.show', (e) ->
    if $(e.target).is('.modal')
      $(this).modal('hide')

  $(document).on 'click', '[data-dismiss="modal"]', (e) ->
    e.preventDefault()
    e.stopPropagation()
    $(this).closest('.modal').modal('hide')

  $(document).on 'keydown.modal', (e) ->
    return unless e.key is 'Escape'

    # Сначала попап или custom-select
    return if $('.popup.is-open').length
    return if $('.custom-select.is-open').length

    $('.modal.show').last().modal('hide')