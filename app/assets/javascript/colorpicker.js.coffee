jQuery.fn.colorPicker = (last_color_title = 'last color') ->

  this.each ->
    input = this

    button = $('<button type="button" class="colorpicker"></button>')
    $(input).after(button)

    pickr = Pickr.create
      el: button[0]
      theme: 'classic'
      default: $(input).val() || '#000000'

      components:
        preview: true
        opacity: false
        hue: true

        interaction:
          hex: false
          input: true
          save: false
          clear: false

    root = pickr.getRoot()

    $(root.app)
      .find('.pcr-last-color')
      .attr('data-tooltip', last_color_title)

    if $(input).val()
      $(root.button)
        .attr('style', "--pcr-color: #{$(input).val()};")

    pickr.on 'change', (color) ->
      return unless color

      hex = color.toHEXA().toString()

      $(input).val(hex)

      $(root.button)
        .attr('style', "--pcr-color: #{hex};")

    pickr.on 'clear', ->
      $(input).val('')

  this