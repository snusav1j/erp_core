window.getPopupClipRect = (el) ->
  clip =
    top: 0
    left: 0
    bottom: window.innerHeight
    right: window.innerWidth

  node = el.parentElement
  while node and node isnt document.body and node isnt document.documentElement
    style = window.getComputedStyle(node)
    oy = style.overflowY
    ox = style.overflowX
    if oy in ['auto', 'scroll', 'hidden'] or ox in ['auto', 'scroll', 'hidden']
      r = node.getBoundingClientRect()
      clip.top    = Math.max(clip.top,    r.top)
      clip.left   = Math.max(clip.left,   r.left)
      clip.bottom = Math.min(clip.bottom, r.bottom)
      clip.right  = Math.min(clip.right,  r.right)
    node = node.parentElement

  clip.width  = Math.max(0, clip.right  - clip.left)
  clip.height = Math.max(0, clip.bottom - clip.top)
  clip


window.getPopupFixedContainer = (el) ->
  node = el.parentElement

  while node and node isnt document.body and node isnt document.documentElement
    style = window.getComputedStyle(node)

    hasTransform = style.transform isnt 'none'
    hasPerspective = style.perspective isnt 'none'
    hasFilter = style.filter isnt 'none'
    hasBackdropFilter = style.backdropFilter isnt 'none'
    hasContain = style.contain in ['layout', 'paint', 'strict', 'content']
    hasWillChange = style.willChange isnt 'auto' and (
      style.willChange.indexOf('transform') >= 0 or
      style.willChange.indexOf('filter') >= 0 or
      style.willChange.indexOf('perspective') >= 0
    )

    return node if hasTransform or hasPerspective or hasFilter or hasBackdropFilter or hasContain or hasWillChange

    node = node.parentElement

  null


window.positionPopup = (popup, el) ->
  return unless popup?.length and popup.hasClass('is-open')
  return unless el?.length

  container = popup.find('.popup-container').first()
  return unless container.length

  rect = el[0].getBoundingClientRect()
  vw = window.innerWidth
  vh = window.innerHeight
  offset = 10
  gap = 5

  clip = getPopupClipRect(el[0])

  btnVisibleH = Math.max(0, Math.min(rect.bottom, clip.bottom) - Math.max(rect.top, clip.top))
  btnVisibleW = Math.max(0, Math.min(rect.right, clip.right) - Math.max(rect.left, clip.left))

  if btnVisibleH <= 0 or btnVisibleW <= 0 or clip.height <= 0 or clip.width <= 0
    popup[0].style.transition = 'none'
    popup[0].style.opacity = '0'
    popup[0].style.pointerEvents = 'none'
    return

  popup[0].style.transition = ''
  popup[0].style.opacity = ''
  popup[0].style.pointerEvents = ''

  popup.css
    position: 'fixed'
    left: 0
    top: 0
    right: 'auto'
    bottom: 'auto'

  popup[0].offsetHeight

  popupWidth = container.outerWidth()
  popupHeight = container.outerHeight()

  position = popup.data('popup-position') || el.data('popup-position') || 'left'

  left = switch position
    when 'right' then rect.right - popupWidth
    when 'center' then rect.left + rect.width / 2 - popupWidth / 2
    else rect.left

  left = Math.max(offset, Math.min(left, vw - popupWidth - offset))

  top = rect.bottom + gap
  if top + popupHeight > vh - offset
    top = rect.top - popupHeight - gap
  if top < offset
    top = offset

  fixedContainer = getPopupFixedContainer(el[0])

  if fixedContainer
    fixedRect = fixedContainer.getBoundingClientRect()
    left -= fixedRect.left
    top -= fixedRect.top

  popup.css
    position: 'fixed'
    left: left
    top: top
    right: 'auto'
    bottom: 'auto'

  if popup[0]
    popup[0].style.clipPath = ''


window.isDescendantPopup = (maybeParent, maybeChild) ->
  return false unless maybeParent?.length and maybeChild?.length
  anchor = maybeChild.data('popup-anchor')
  return false unless anchor?.length

  current = anchor
  depth = 0
  while current?.length and depth < 20
    parent = current.closest('.popup')
    return true if parent.length and parent[0] == maybeParent[0]
    nextAnchor = if parent.length then parent.data('popup-anchor') else null
    break unless nextAnchor?.length
    current = nextAnchor
    depth += 1
  false


window.collectParentPopups = (el) ->
  result = []
  parent = el.closest('.popup')
  return result unless parent.length

  result.push parent[0]
  anchor = parent.data('popup-anchor')
  depth = 0
  while anchor?.length and depth < 20
    gp = anchor.closest('.popup')
    break unless gp.length
    result.push gp[0]
    anchor = gp.data('popup-anchor')
    depth += 1
  result


window.closePopup = (popup) ->
  return unless popup?.length and popup.hasClass('is-open')

  $('.popup.is-open').not(popup).each ->
    other = $(this)
    other.removeClass('is-open') if isDescendantPopup(popup, other)

  if popup[0]
    popup[0].style.clipPath = ''
    popup[0].style.opacity = ''
    popup[0].style.pointerEvents = ''

  popup.removeClass('is-open')
  popup.removeData('popup-anchor')
  $('.images-carousel-slide').removeClass('control-open')


window.closeOtherPopups = (keepPopup, keepParents = []) ->
  $('.popup.is-open').each ->
    opened = $(this)
    return if opened[0] == keepPopup?[0]

    isParent = false
    for p in keepParents
      if p == opened[0]
        isParent = true
        break
    return if isParent

    closePopup(opened)


window.openPopup = (popup, el) ->
  return unless popup?.length and el?.length

  modal = el.closest('.modal')

  maxZIndex = 1040

  if modal.length
    z = parseInt(modal.css('z-index'), 10)
    maxZIndex = z if !isNaN(z) and z > maxZIndex

  $('.popup.is-open').each ->
    zIndex = parseInt($(this).css('z-index'), 10)
    maxZIndex = zIndex if !isNaN(zIndex) and zIndex > maxZIndex

  parents = collectParentPopups(el)
  closeOtherPopups(popup, parents)

  popup.css('z-index', maxZIndex + 10)
  popup.data('popup-anchor', el)
  popup.data('popup-position', el.data('popup-position') || 'left')

  if popup[0]
    popup[0].style.clipPath = ''
    popup[0].style.opacity = ''
    popup[0].style.pointerEvents = ''

  popup[0].offsetHeight

  popup.addClass('is-open')
  positionPopup(popup, el)

  requestAnimationFrame ->
    return unless popup.hasClass('is-open')
    positionPopup(popup, el)


pendingDelete = null


window.commitPendingDelete = ->
  return unless pendingDelete

  popupId = pendingDelete.popupId
  popupEl = pendingDelete.popupEl

  if popupEl?.parentNode
    popupEl.parentNode.removeChild(popupEl)
  else if popupId
    el = document.getElementById(popupId)
    el?.parentNode?.removeChild(el)

  if popupId
    document.querySelectorAll("[data-popup-id='#{popupId}']").forEach (t) ->
      t.parentNode?.removeChild(t)

  pendingDelete = null


$(document).off '.dtPopup'
$(window).off '.dtPopup'


$(document).on 'click.dtPopup', '[data-popup-id]', (e) ->
  e.preventDefault()
  e.stopPropagation()
  e.stopImmediatePropagation()

  el = $(this)
  popupId = el.attr('data-popup-id') or el.data('popup-id')
  return unless popupId

  popup = $("##{popupId}")
  return unless popup.length

  if popup.hasClass('is-open')
    closePopup(popup)
    return

  openPopup(popup, el)

  if window._dtPopupRO
    container = popup.find('.popup-container').first()
    window._dtPopupRO.observe(container[0]) if container.length


$(document).on 'click.dtPopup', '[data-popup-close]', (e) ->
  e.preventDefault()
  e.stopPropagation()
  closePopup($(this).closest('.popup'))


$(document).on 'click.dtPopup', '.popup', (e) ->
  e.stopPropagation()

  clickedPopup = $(e.target).closest('.popup')
  return unless clickedPopup.length

  $('.popup.is-open').each ->
    opened = $(this)
    return if opened[0] == clickedPopup[0]
    closePopup(opened) if isDescendantPopup(clickedPopup, opened)


$(document).on 'click.dtPopup', (e) ->
  target = $(e.target)
  return if target.closest('.popup, [data-popup-id], #confirm-alert-modal, .images-carousel-control, .images-carousel-thumbnail').length

  targetModal = target.closest('.modal')

  $('.popup.is-open').each ->
    popup = $(this)
    anchor = popup.data('popup-anchor')
    popupModal = anchor?.closest('.modal')

    if targetModal.length
      closePopup(popup) if popupModal?.length and popupModal[0] == targetModal[0]
    else
      closePopup(popup) unless popupModal?.length


$(document).on 'keydown.dtPopup', (e) ->
  return unless e.key == 'Escape'

  closed = false

  activeModal = $('.modal:visible').last()
  if activeModal.length
    $('.popup.is-open').each ->
      popup = $(this)
      anchor = popup.data('popup-anchor')
      popupModal = anchor?.closest('.modal')
      if popupModal?.length and popupModal[0] == activeModal[0]
        closePopup(popup)
        closed = true
  else
    $('.popup.is-open').each ->
      closePopup($(this))
      closed = true

  if closed
    e.preventDefault()
    e.stopImmediatePropagation()


repositionAllPopups = ->
  $('.popup.is-open').each ->
    popup = $(this)
    el = popup.data('popup-anchor')
    positionPopup(popup, el) if el?.length


$(window).on 'scroll.dtPopup resize.dtPopup', repositionAllPopups
document.addEventListener 'scroll', repositionAllPopups, true


if window.ResizeObserver
  window._dtPopupRO = new ResizeObserver (entries) ->
    entries.forEach (entry) ->
      container = $(entry.target)
      popup = container.closest('.popup')
      el = popup.data('popup-anchor')
      positionPopup(popup, el) if el?.length


document.addEventListener 'click', ((e) ->
  link = e.target.closest('a[data-method="delete"]')
  return unless link

  popup = link.closest('.popup')
  return unless popup?.id

  pendingDelete =
    popupId: popup.id
    popupEl: popup
    href: link.getAttribute('href')
), true


$(document).on 'ajax:success', 'a[data-method="delete"]', ->
  commitPendingDelete()


$(document).ajaxSuccess (event, xhr, settings) ->
  return unless pendingDelete
  return unless xhr.status >= 200 and xhr.status < 300

  method = (settings.type or '').toUpperCase()
  url = settings.url or ''
  data = String(settings.data or '')
  href = pendingDelete.href or ''

  isDelete = method == 'DELETE' or /_method=delete/i.test(data)
  isDelete = true if href and url.indexOf(href.replace(/^https?:\/\/[^/]+/, '')) >= 0
  isDelete = true if /\/versions\/\d+/.test(url) and method in ['POST', 'DELETE']

  commitPendingDelete() if isDelete


$(document).on 'ajax:error', 'a[data-method="delete"]', ->
  pendingDelete = null