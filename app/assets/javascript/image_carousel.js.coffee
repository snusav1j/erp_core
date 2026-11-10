images_carousel_interval = 2500


close_images_carousel_popup = (carousel) ->

  $('.popup.is-open').each ->
    popup = $(this)
    anchor = popup.data('popup-anchor')

    return unless anchor?.length
    return unless anchor.closest('.images-carousel')[0] == carousel[0]

    closePopup(popup)

  carousel.find('.images-carousel-slide > .popup-btn').removeClass('is-open')


reset_images_carousel_timer = (carousel) ->

  clearTimeout(carousel.data('images-carousel-timer'))
  carousel.removeData('images-carousel-timer')

  return if carousel.find('.images-carousel-image:hover').length
  return if carousel.find('.images-carousel-thumbnails:hover').length
  return if carousel.find('.images-carousel-slide > .popup-btn:hover').length

  popup = $('.popup.is-open').filter ->
    anchor = $(this).data('popup-anchor')
    anchor?.length and anchor.closest('.images-carousel')[0] == carousel[0]

  return if popup.length and popup.is(':hover')

  timer = setTimeout ->

    slides     = carousel.find('.images-carousel-slide')
    thumbnails = carousel.find('.images-carousel-thumbnail')
    popup      = $('.popup.is-open').filter ->
      anchor = $(this).data('popup-anchor')
      anchor?.length and anchor.closest('.images-carousel')[0] == carousel[0]

    return reset_images_carousel_timer(carousel) if carousel.find('.images-carousel-image:hover').length
    return reset_images_carousel_timer(carousel) if carousel.find('.images-carousel-thumbnails:hover').length
    return reset_images_carousel_timer(carousel) if carousel.find('.images-carousel-slide > .popup-btn:hover').length
    return reset_images_carousel_timer(carousel) if popup.length and popup.is(':hover')
    return unless slides.length > 1

    close_images_carousel_popup(carousel)

    current = slides.index(slides.filter('.active'))
    current = if current >= slides.length - 1 then 0 else current + 1

    slides.removeClass('active').eq(current).addClass('active')
    thumbnails.removeClass('active').eq(current).addClass('active')

    thumbnails.eq(current)[0]?.scrollIntoView
      behavior: 'smooth'
      block: 'nearest'
      inline: 'nearest'

    reset_images_carousel_timer(carousel)

  , images_carousel_interval

  carousel.data('images-carousel-timer', timer)


window.reset_images_carousel_timer = reset_images_carousel_timer


$(document).on 'mouseenter', '.images-carousel-image', ->

  carousel = $(this).closest('.images-carousel')

  clearTimeout(carousel.data('images-carousel-timer'))
  carousel.removeData('images-carousel-timer')


$(document).on 'mouseleave', '.images-carousel-image', ->

  reset_images_carousel_timer($(this).closest('.images-carousel'))


$(document).on 'mouseenter', '.images-carousel-thumbnails', ->

  carousel = $(this).closest('.images-carousel')

  clearTimeout(carousel.data('images-carousel-timer'))
  carousel.removeData('images-carousel-timer')


$(document).on 'mouseleave', '.images-carousel-thumbnails', ->

  reset_images_carousel_timer($(this).closest('.images-carousel'))


$(document).on 'mouseenter', '.images-carousel-slide > .popup-btn', ->

  carousel = $(this).closest('.images-carousel')

  clearTimeout(carousel.data('images-carousel-timer'))
  carousel.removeData('images-carousel-timer')


$(document).on 'mouseleave', '.images-carousel-slide > .popup-btn', ->

  reset_images_carousel_timer($(this).closest('.images-carousel'))


$(document).on 'mouseenter', '.popup[id^="images-carousel-popup-"].is-open', ->

  popup = $(this)
  anchor = popup.data('popup-anchor')

  return unless anchor?.length

  carousel = anchor.closest('.images-carousel')

  clearTimeout(carousel.data('images-carousel-timer'))
  carousel.removeData('images-carousel-timer')


$(document).on 'mouseleave', '.popup[id^="images-carousel-popup-"].is-open', ->

  popup = $(this)
  anchor = popup.data('popup-anchor')

  return unless anchor?.length

  reset_images_carousel_timer(anchor.closest('.images-carousel'))


$(document).on 'click', '.images-carousel-add', ->

  form_id = $(this).data('form-id')
  return unless form_id

  $("##{form_id}").find('.images-carousel-input').click()


$(document).on 'change', '.images-carousel-input', ->

  input = this
  form  = $(input).closest('form')[0]

  return unless input.files.length

  form_data = new FormData()

  form_data.append('product[images][]', file) for file in input.files

  $.ajax
    url: "#{form.action}/upload_image"
    type: 'POST'
    data: form_data
    processData: false
    contentType: false
    dataType: 'script'
    headers:
      'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')


$(document).on 'click', '.images-carousel-arrow-prev, .images-carousel-arrow-next', ->

  carousel   = $(this).closest('.images-carousel')
  slides     = carousel.find('.images-carousel-slide')
  thumbnails = carousel.find('.images-carousel-thumbnail')

  close_images_carousel_popup(carousel)

  current = slides.index(slides.filter('.active'))
  isNext  = $(this).hasClass('images-carousel-arrow-next')

  if isNext
    current = if current >= slides.length - 1 then 0 else current + 1
  else
    current = if current <= 0 then slides.length - 1 else current - 1

  slides.removeClass('active').eq(current).addClass('active')
  thumbnails.removeClass('active').eq(current).addClass('active')

  thumbnails.eq(current)[0]?.scrollIntoView
    behavior: 'smooth'
    block: 'nearest'
    inline: 'nearest'

  reset_images_carousel_timer(carousel)


$(document).on 'click', '.images-carousel-thumbnail', ->

  thumbnail = $(this)
  carousel  = thumbnail.closest('.images-carousel')
  index     = thumbnail.data('index')

  close_images_carousel_popup(carousel)

  carousel.find('.images-carousel-slide').removeClass('active').eq(index).addClass('active')
  carousel.find('.images-carousel-thumbnail').removeClass('active')

  thumbnail.addClass('active')

  thumbnail[0]?.scrollIntoView
    behavior: 'smooth'
    block: 'nearest'
    inline: 'nearest'

  reset_images_carousel_timer(carousel)


$(document).on 'contextmenu', '.images-carousel-thumbnail', (e) ->

  e.preventDefault()
  e.stopPropagation()

  thumb    = $(this)
  carousel = thumb.closest('.images-carousel')
  popupId  = thumb.data('carousel-popup-id')

  return unless popupId

  popup = $("##{popupId}")

  return unless popup.length

  carousel.find('.images-carousel-slide > .popup-btn').removeClass('is-open')

  trigger = carousel.find(".images-carousel-slide > .popup-btn[data-popup-id='#{popupId}']")

  popup.find('.images-carousel-add').remove()

  if popup.hasClass('is-open')
    closePopup(popup)
  else
    trigger.addClass('is-open')
    openPopup(popup, thumb)


window.fix_images_carousel_scroll = ->

  document.querySelectorAll('.images-carousel-thumbnails').forEach (el) ->

    el.addEventListener 'wheel', (e) ->

      if el.scrollWidth > el.clientWidth
        e.preventDefault()
        e.stopPropagation()
        el.scrollLeft += e.deltaY

    , { passive: false }


window.fix_images_carousel_scroll()


document.addEventListener 'click', (e) ->

  button = e.target.closest('.images-carousel-slide > .popup-btn[data-popup-id]')

  return unless button

  button.classList.add('is-open')

, true


document.addEventListener 'click', (e) ->

  link = e.target.closest('[id^="images-carousel-popup-"] [data-action="set-main-image"]')

  return unless link

  e.preventDefault()
  e.stopPropagation()
  e.stopImmediatePropagation()

  link = $(link)
  image_id = link.data('image-id')
  url = link.attr('href')

  return unless image_id && url

  $.ajax
    url: url
    type: 'POST'
    data:
      image_id: image_id
    dataType: 'script'
    headers:
      'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')

  closePopup(link.closest('.popup'))
  $('.images-carousel-slide > .popup-btn').removeClass('is-open')

, true


document.addEventListener 'click', (e) ->

  link = e.target.closest('[id^="images-carousel-popup-"] [data-action="delete-image"]')

  return unless link

  e.preventDefault()
  e.stopPropagation()
  e.stopImmediatePropagation()

  link = $(link)
  image_id = link.data('image-id')
  url = link.attr('href')

  return unless image_id && url

  $.ajax
    url: url
    type: 'DELETE'
    data:
      image_id: image_id
    dataType: 'script'
    headers:
      'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')

  closePopup(link.closest('.popup'))
  $('.images-carousel-slide > .popup-btn').removeClass('is-open')

, true


$(document).on 'turbo:load', ->

  $('.images-carousel').each ->
    reset_images_carousel_timer($(this))