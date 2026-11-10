tooltip = null

$(document).on 'mouseenter', '[data-tooltip]', ->

  el = $(this)

  tooltip?.remove()

  tooltip = $('<div class="tooltip-custom"></div>')
  tooltip.html(el.attr('data-tooltip'))

  $('body').append(tooltip)

  rect = el[0].getBoundingClientRect()

  placement = 'top'

  tooltip.css(
    left: rect.left + rect.width / 2
    top: rect.top - 5
    transform: 'translate(-50%, -100%)'
  )

  requestAnimationFrame ->
    return unless tooltip

    tooltipRect = tooltip[0].getBoundingClientRect()

    viewportWidth = document.documentElement.clientWidth
    viewportHeight = document.documentElement.clientHeight

    shift = 0

    if tooltipRect.right > viewportWidth - 10
      shift = viewportWidth - 10 - tooltipRect.right

    if tooltipRect.left < 10
      shift = 10 - tooltipRect.left

    if tooltipRect.top < 10
      placement = 'bottom'

      tooltip.css(
        top: rect.bottom + 5
        transform: "translate(calc(-50% + #{shift}px), 0)"
      )
    else
      tooltip.css(
        transform: "translate(calc(-50% + #{shift}px), -100%)"
      )

    tooltip.addClass('show')
  , 0


$(document).on 'mouseleave', '[data-tooltip]', ->
  tooltip?.remove()
  tooltip = null


$(document).on 'click', (e) ->
  return if $(e.target).closest('[data-tooltip]').length
  return if tooltip and $(e.target).closest(tooltip).length

  tooltip?.remove()
  tooltip = null
