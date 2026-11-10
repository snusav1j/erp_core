$ ->

  dragged = null
  candidate = null
  startX = 0
  startY = 0
  offsetX = 0
  offsetY = 0
  threshold = 3

  # === MOUSEDOWN ===
  $(document).on 'mousedown', 'table .draggable', (e) ->

    # если клик по кнопке — выходим
    if $(e.target).closest('button, .btn, .btn-sm').length
      return

    parent = $(this).closest('.draggable-parent')
    return unless parent.length

    candidate = parent

    rect = candidate[0].getBoundingClientRect()

    startX = e.clientX
    startY = e.clientY

    offsetX = e.clientX - rect.left
    offsetY = e.clientY - rect.top

    e.preventDefault()


  # === MOUSEMOVE ===
  $(document).on 'mousemove', (e) ->

    return unless candidate?

    dx = Math.abs(e.clientX - startX)
    dy = Math.abs(e.clientY - startY)

    # если drag ещё не начался — проверяем threshold
    unless dragged?
      return if dx < threshold and dy < threshold

      # начинаем drag
      dragged = candidate
      rect = dragged[0].getBoundingClientRect()

      dragged.css
        position: 'absolute'
        left: rect.left + window.scrollX
        top: rect.top + window.scrollY
        width: rect.width
        margin: 0
        zIndex: 2147483647

      dragged.addClass 'dragging'

    # если уже тащим — двигаем
    if dragged?
      newLeft = e.clientX - offsetX
      newTop  = e.clientY - offsetY

      dragged.css
        left: newLeft
        top:  newTop
        transform: ''


  # === MOUSEUP / ESC ===
  $(document).on 'mouseup keydown', (e) ->

    return unless candidate? or dragged?

    if e.type == 'mouseup' or (e.type == 'keydown' and e.key == 'Escape')
      if dragged?
        dragged.removeClass 'dragging'
        dragged.css zIndex: ''

      dragged = null
      candidate = null