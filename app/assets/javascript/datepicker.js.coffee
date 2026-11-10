jQuery.fn.datePicker = ->

  this.each ->

    flatpickr(this,
      locale: flatpickr.l10ns.ru
      dateFormat: 'Y-m-d'
      allowInput: true
    )

  this

jQuery.fn.datetimePicker = ->

  this.each ->

    flatpickr(this,
      locale: flatpickr.l10ns.ru
      enableTime: true
      dateFormat: 'Y-m-d H:i'
      allowInput: true
    )

  this

jQuery.fn.datetimePickerLimits = (options) ->

  this.each ->

    flatpickr(this,
      locale: flatpickr.l10ns.ru
      enableTime: true
      dateFormat: 'Y-m-d H:i'
      allowInput: true
      plugins: [
        new minMaxTimePlugin(
          table: options.table
        )
      ]
    )

  this

$(document).ready ->
  $('.datepicker').datePicker()
  $('.datetime-picker').datetimePicker()