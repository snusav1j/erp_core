window.toastr =
  toastr_show_time: 50
  toastr_life_time: 2000
  toastr_remove_time: 300
  # toastr_position: if window.innerWidth <= 767 then 'center' else 'right_top'
  toastr_position: 'center'

  _position: (container, position = null) ->
    window_width = window.innerWidth
    window_height = window.innerHeight
    toastr_width = container.offsetWidth
    toastr_height = container.offsetHeight
    margin = 7
    bottom_margin = margin

    position = position || window.toastr.toastr_position

    switch position
      when 'left', 'left_top'
        container.style.left = "#{margin}px"
        container.style.right = 'auto'
        container.style.top = "#{margin}px"
        container.style.bottom = 'auto'

      when 'right', 'right_top'
        container.style.left = 'auto'
        container.style.right = "#{margin}px"
        container.style.top = "#{margin}px"
        container.style.bottom = 'auto'

      when 'left_bottom'
        container.style.left = "#{margin}px"
        container.style.right = 'auto'
        container.style.top = 'auto'
        container.style.bottom = "#{bottom_margin}px"

      when 'right_bottom'
        container.style.left = 'auto'
        container.style.right = "#{margin}px"
        container.style.top = 'auto'
        container.style.bottom = "#{bottom_margin}px"

      when 'center_bottom'
        left = (window_width - toastr_width) / 2

        container.style.left = "#{Math.max(left, 10)}px"
        container.style.right = 'auto'
        container.style.top = 'auto'
        container.style.bottom = "#{bottom_margin}px"

      when 'center_top'
        left = (window_width - toastr_width) / 2

        container.style.left = "#{Math.max(left, 10)}px"
        container.style.right = 'auto'
        container.style.top = "#{margin}px"
        container.style.bottom = 'auto'

      else
        left = (window_width - toastr_width) / 2

        container.style.left = "#{Math.max(left, 10)}px"
        container.style.right = 'auto'
        container.style.top = "#{margin}px"
        container.style.bottom = 'auto'

  _show: (status, options = {}) ->
    icons =
      success: '<span class="ph ph-seal-check"></span>'
      danger: '<span class="ph ph-seal-warning"></span>'
      warning: '<span class="ph ph-seal-warning"></span>'
      primary: '<span class="ph ph-seal-warning"></span>'

    message = if typeof options.message is 'string' then options.message else ''
    description = if typeof options.description is 'string' then options.description else ''
    details = if typeof options.details is 'string' then options.details else ''

    currentLifeTime = options.life_time || window.toastr.toastr_life_time
    position = options.position || window.toastr.toastr_position

    document.querySelectorAll('.custom-toastr-container:not(#toastr-template)').forEach (el) ->
      el.remove()

    toastrContainer = document.querySelector('#toastr-template')?.cloneNode(true)

    return unless toastrContainer

    toastrContainer.removeAttribute('id')
    toastrContainer.dataset.position = position
    toastrContainer.classList.add("custom-toastr-#{status}")

    toastrIconBlock = toastrContainer.querySelector('.custom-toastr-icon')
    toastrMessage = toastrContainer.querySelector('.custom-toastr-message')
    toastrDescription = toastrContainer.querySelector('.custom-toastr-description')
    toastrMessageBlock = toastrContainer.querySelector('.custom-toastr-message-block')
    toastrDetails = toastrContainer.querySelector('.custom-toastr-details')
    toastrProgress = toastrContainer.querySelector('.custom-toastr-progress')
    pauseTimerIcon = toastrContainer.querySelector('.progress-pause-timer')
    closeIcon = toastrContainer.querySelector('.close-icon')

    toastrIconBlock.classList.add("color-badge-#{status}")

    if icons[status]?
      toastrIconBlock.innerHTML = icons[status]

    defaultMessage = toastrContainer.dataset[status]
    defaultDescription = toastrContainer.dataset.defaultDescription

    toastrMessage.innerHTML = message || defaultMessage
    toastrDescription.innerHTML = description || defaultDescription

    if details
      toastrDetails.innerHTML = details
    else
      toastrDetails.remove()

    document.body.prepend(toastrContainer)

    window.toastr._position(toastrContainer, position)

    toastrProgress.style.setProperty('--toastr-life-time', "#{currentLifeTime}ms")

    hideTimeout = null
    removeTimeout = null
    pauseIconTimeout = null

    remainingTime = currentLifeTime
    startedAt = null
    paused = false
    messageBlockHovered = false

    if toastrDetails
      toastrDetails.addEventListener 'click', (event) ->
        event.stopPropagation()

    if toastrMessageBlock and closeIcon
      toastrMessageBlock.addEventListener 'mouseenter', ->
        messageBlockHovered = true

        closeIcon.classList.add('show')

        if pauseIconTimeout
          clearTimeout(pauseIconTimeout)
          pauseIconTimeout = null

        pauseTimerIcon.classList.remove('show')
        pauseTimerIcon.style.display = 'none'

      toastrMessageBlock.addEventListener 'mouseleave', ->
        messageBlockHovered = false

        closeIcon.classList.remove('show')

        if paused
          pauseTimerIcon.style.display = 'block'

          pauseIconTimeout = setTimeout ->
            return unless paused or messageBlockHovered

            pauseTimerIcon.classList.add('show')
            pauseIconTimeout = null
          , 0

    showToastr = ->
      window.toastr._position(toastrContainer, position)
      toastrContainer.classList.add('show-toastr-container')

      startedAt = Date.now()

      requestAnimationFrame ->
        toastrProgress.classList.add('active')

      hideTimeout = setTimeout ->
        toastrContainer.classList.remove('show-toastr-container')

        removeTimeout = setTimeout ->
          toastrContainer.remove()
        , window.toastr.toastr_remove_time
      , remainingTime

    setTimeout ->
      showToastr()
    , window.toastr.toastr_show_time

    toastrContainer.addEventListener 'mouseenter', ->
      return if paused or not startedAt

      paused = true

      if hideTimeout
        clearTimeout(hideTimeout)

      if pauseIconTimeout
        clearTimeout(pauseIconTimeout)
        pauseIconTimeout = null

      elapsedTime = Date.now() - startedAt
      remainingTime = Math.max(0, remainingTime - elapsedTime)

      computedStyle = window.getComputedStyle(toastrProgress)
      transform = computedStyle.transform

      scale = 1

      if transform and transform isnt 'none'
        matrix = new DOMMatrix(transform)
        scale = matrix.a

      toastrProgress.style.transition = 'none'
      toastrProgress.style.transform = "scaleX(#{scale})"

      toastrProgress.offsetWidth

      unless messageBlockHovered
        pauseTimerIcon.style.display = 'block'

        pauseIconTimeout = setTimeout ->
          return unless paused or messageBlockHovered

          pauseTimerIcon.classList.add('show')
          pauseIconTimeout = null
        , 0

    toastrContainer.addEventListener 'mouseleave', ->
      return unless paused

      paused = false

      if pauseIconTimeout
        clearTimeout(pauseIconTimeout)
        pauseIconTimeout = null

      pauseTimerIcon.classList.remove('show')
      pauseTimerIcon.style.display = 'none'

      closeIcon.classList.remove('show')

      toastrProgress.classList.remove('active')

      toastrProgress.offsetWidth

      toastrProgress.style.transition = "transform #{remainingTime}ms linear"
      toastrProgress.style.transform = 'scaleX(0)'

      toastrProgress.offsetWidth

      startedAt = Date.now()

      hideTimeout = setTimeout ->
        toastrContainer.classList.remove('show-toastr-container')

        removeTimeout = setTimeout ->
          toastrContainer.remove()
        , window.toastr.toastr_remove_time
      , remainingTime

    toastrContainer.addEventListener 'click', ->
      if hideTimeout
        clearTimeout(hideTimeout)

      if removeTimeout
        clearTimeout(removeTimeout)

      if pauseIconTimeout
        clearTimeout(pauseIconTimeout)
        pauseIconTimeout = null

      toastrContainer.classList.remove('show-toastr-container')

      setTimeout ->
        toastrContainer.remove()
      , window.toastr.toastr_remove_time

  success: (options = {}) -> window.toastr._show('success', options)
  danger: (options = {}) -> window.toastr._show('danger', options)
  warning: (options = {}) -> window.toastr._show('warning', options)
  primary: (options = {}) -> window.toastr._show('primary', options)

window.addEventListener 'resize', ->
  container = document.querySelector('.custom-toastr-container:not(#toastr-template)')

  if container
    position = container.dataset.position || window.toastr.toastr_position
    window.toastr._position(container, position)