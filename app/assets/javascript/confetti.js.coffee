CONFETTI_CONFIG =
  particles_count: 25
  distance_min: 20
  distance_max: 30
  rotate_min: -450
  rotate_max: 450
  size_width: 5
  size_height: 5
  circle_chance: 0.3
  animation_duration: 400
  animation_delay: 50
  remove_delay: 700

  z_index: 1
  modal_z_index: 100000000
  modal_selector: '.modal'

  center_x: 0
  center_y: 0

  colors: [
    '#24a5df'
    '#20b866'
    '#f29f2d'
    '#e74755'
    '#9b59b6'
    '#f1c40f'
    '#ffffff'
  ]

$.fn.createConfetti = ->
  @each ->
    target = this
    $target = $(target)

    rect = target.getBoundingClientRect()
    return unless rect.width and rect.height

    is_modal = $target.closest(CONFETTI_CONFIG.modal_selector).length > 0
    z_index = if is_modal then CONFETTI_CONFIG.modal_z_index else CONFETTI_CONFIG.z_index

    burst = $('<div class="confetti-burst"></div>')

    burst.css
      position: 'fixed'
      left: '0'
      top: '0'
      zIndex: z_index
      pointerEvents: 'none'

    update_position = ->
      return unless $.contains(document, target)

      rect = target.getBoundingClientRect()

      burst.css
        left: "#{rect.left + rect.width / 2 + CONFETTI_CONFIG.center_x}px"
        top: "#{rect.top + rect.height / 2 + CONFETTI_CONFIG.center_y}px"

    for i in [0...CONFETTI_CONFIG.particles_count]
      angle = Math.random() * Math.PI * 2
      distance = CONFETTI_CONFIG.distance_min + Math.random() * (CONFETTI_CONFIG.distance_max - CONFETTI_CONFIG.distance_min)
      x = Math.cos(angle) * distance
      y = Math.sin(angle) * distance
      rotate = CONFETTI_CONFIG.rotate_min + Math.random() * (CONFETTI_CONFIG.rotate_max - CONFETTI_CONFIG.rotate_min)
      color = CONFETTI_CONFIG.colors[Math.floor(Math.random() * CONFETTI_CONFIG.colors.length)]

      particle = $('<span class="confetti-particle"></span>')

      if Math.random() < CONFETTI_CONFIG.circle_chance
        particle.addClass('confetti-particle--circle')

      particle.css
        width: "#{CONFETTI_CONFIG.size_width}px"
        height: "#{CONFETTI_CONFIG.size_height}px"
        background: color
        animationDuration: "#{CONFETTI_CONFIG.animation_duration}ms"
        animationDelay: "#{Math.random() * CONFETTI_CONFIG.animation_delay}ms"

      particle[0].style.setProperty('--confetti-x', "#{x}px")
      particle[0].style.setProperty('--confetti-y', "#{y}px")
      particle[0].style.setProperty('--confetti-rotate', "#{rotate}deg")

      burst.append(particle)

    $('body').append(burst)

    update_position()

    document.addEventListener('scroll', update_position, true)
    window.addEventListener('resize', update_position)

    setTimeout ->
      document.removeEventListener('scroll', update_position, true)
      window.removeEventListener('resize', update_position)
      burst.remove()
    , CONFETTI_CONFIG.remove_delay

  this