class CustomSelect
  constructor: (@select, @options = {}) ->
    @select = $(@select)
    @multiple = @select.prop('multiple')
    @queryInput = @options.queryInput || null
    @queryInputs = if $.isArray(@queryInput) then @queryInput else [@queryInput]
    @queryInputs = @queryInputs.filter (input) -> input
    @keyboardSearch = ''
    @keyboardSearchTimer = null

    @ajax = @options.ajax || if @options.url
      url: @options.url
      method: @options.method || 'GET'
      loadOnInit: @options.loadOnInit || false
      data: @options.data
      getCollection: @options.getCollection
    else
      null

    @search = @options.search
    @prompt = @options.prompt || @select.attr('data-prompt')
    @maxWidth = @options.maxWidth || null
    @width = @options.width || null
    @searchDelay = @options.searchDelay || 300
    @searchTimer = null
    @queryInputTimer = null
    @ajaxRequest = null
    @lastLoadedQuery = null
    @collection = []
    @searchCollection = []
    @optionsContainer = null
    @initialized = false
    @highlightedIndex = -1
    @instanceId = "customSelect#{CustomSelect.instanceCount += 1}"

    @build()
    @syncDisabled()
    @bind()
    @renderOptions()
    @syncValue()
    @setWidth()

    if @ajax?.loadOnInit
      @loadAjax('')
    else if @ajax and @hasSelectedValues()
      @loadSelectedAjax()
    else if @ajax and @hasQueryInputValue()
      @loadInitialQueryInput()
    else if @ajax
      @setInitialized()
    else
      @setInitialized()

  build: ->
    @select.addClass('custom-select-native')

    @wrapper = $('<div class="custom-select"></div>')
    @wrapper.addClass('multiple-select') if @multiple

    @control = $('<div class="custom-select__control"></div>')
    @control.addClass('is-shimmering') if @ajax

    @value = $('<div class="custom-select__value"></div>')

    @control.append(@value)

    @dropdown = $('<div class="custom-select__dropdown"></div>')

    if @search
      @searchWrapper = $('<div class="custom-select__search"></div>')
      @searchInput = $('<input type="text" class="custom-select__search-input">')

      @searchWrapper.append(@searchInput)
      @dropdown.append(@searchWrapper)

    @wrapper.append(@control)
    @wrapper.append(@dropdown)

    @select.after(@wrapper)

  bind: ->
    @control.attr('tabindex', '0')

    @dropdown.on 'wheel.customSelect', (e) =>
      element = e.target.closest('.custom-select__options')

      return unless element

      delta = e.originalEvent.deltaY

      atTop = element.scrollTop <= 0
      atBottom = element.scrollTop + element.clientHeight >= element.scrollHeight

      if (delta < 0 and atTop) or (delta > 0 and atBottom)
        e.preventDefault()

      e.stopPropagation()

    @control.on 'click.customSelect', (e) =>
      e.preventDefault()
      @toggle()

    @control.on 'keydown.customSelect', (e) =>
      @handleKeydown(e)

    $(document).on "mousedown.#{@instanceId}", (e) =>
      return if $(e.target).closest(@wrapper).length

      @close()
    if @search
      @searchInput?.on 'input.customSelect', =>
        @searchOptions()

      @searchInput?.on 'keydown.customSelect', (e) =>
        @handleKeydown(e)

    if @queryInputs.length
      @queryInputs.forEach (input) =>
        $(input).on "input.#{@instanceId}", =>
          @scheduleQueryInputLoad()

        $(input).on "keyup.#{@instanceId}", =>
          @scheduleQueryInputLoad()

        $(input).on "change.#{@instanceId}", =>
          @scheduleQueryInputLoad()

    @select.on 'change.customSelect', =>
      @syncValue()

      if @wrapper.hasClass('is-open')
        @renderCollection(@getVisibleCollection())
        @setWidth(@getVisibleCollection())
      else
        @setWidth()

  getQueryInputValues: ->
    return [] unless @queryInputs.length

    @queryInputs.map (input) ->
      $.trim($(input).val() || '')

  getQueryInputQuery: ->
    values = @getQueryInputValues()

    return '' unless values.length
    return '' if values[0].length < 3
    return '' if values.slice(1).some (value) -> value.length < 1

    values.join(' ')

  hasQueryInputValue: ->
    query = @getQueryInputQuery()

    query.length > 0

  hasSelectedValues: ->
    values = @select.val() || []

    values = [values] unless $.isArray(values)

    values.some (value) ->
      String(value).length > 0

  setInitialized: ->
    return if @initialized

    @initialized = true
    @control.removeClass('is-shimmering')

    if @wrapper.hasClass('is-open')
      @setWidth(@getVisibleCollection())
    else
      @setWidth()

  setShimmering: ->
    return unless @ajax

    @control.addClass('is-shimmering')

  removeShimmering: ->
    @control.removeClass('is-shimmering')

  toggle: ->
    if @wrapper.hasClass('is-open')
      @close()
    else
      @open()

  open: ->
    $('.custom-select.is-open').not(@wrapper).each ->
      instance = $(this).prev('.custom-select-native').data('customSelect')

      if instance
        instance.close()
      else
        $(this).removeClass('is-open')

    @wrapper.addClass('is-open')
    @searchInput?.val('')
    @highlightedIndex = -1

    if @ajax
      if @queryInputs.length
        collection = @searchCollection

        if !collection.length
          collection = @collection

        @renderCollection(collection)
        @setWidth(collection)
      else if @ajax.loadOnInit
        @renderCollection(@collection)
        @setWidth(@collection)
      else
        @renderCollection(@searchCollection)
        @setWidth(@searchCollection)
    else
      @renderCollection(@collection)
      @setWidth(@collection)

    if @search
      @searchInput?.focus()
    else
      @control.focus()

  close: ->
    @wrapper.removeClass('is-open')
    @searchInput?.val('')
    @keyboardSearch = ''
    clearTimeout(@keyboardSearchTimer)
    @highlightedIndex = -1
    @setWidth()

  searchByKeyboard: (key) ->
    clearTimeout(@keyboardSearchTimer)

    @keyboardSearch += key.toLowerCase()

    query = @keyboardSearch

    @keyboardSearchTimer = setTimeout =>
      @keyboardSearch = ''
    , 700

    collection = @getVisibleCollection()

    return unless collection?.length

    startIndex = @highlightedIndex + 1
    startIndex = 0 if startIndex >= collection.length

    index = -1

    for i in [startIndex...collection.length]
      value = String(collection[i].value || '').toLowerCase()

      if value.startsWith(query)
        index = i
        break

    if index < 0
      for i in [0...startIndex]
        value = String(collection[i].value || '').toLowerCase()

        if value.startsWith(query)
          index = i
          break

    return if index < 0

    @highlightedIndex = index

    options = @optionsContainer?.find('.custom-select__option')

    return unless options?.length

    @updateHighlight(options)

  handleKeydown: (e) ->
    return unless @wrapper.hasClass('is-open')

    switch e.key
      when 'ArrowDown'
        e.preventDefault()
        @moveHighlight(1)

      when 'ArrowUp'
        e.preventDefault()
        @moveHighlight(-1)

      when 'Enter'
        e.preventDefault()
        @selectHighlighted()

      when 'Escape'
        e.preventDefault()
        e.stopImmediatePropagation()
        @close()

      else
        return if @searchInput?.length and $(e.target).is(@searchInput)

        if e.key.length == 1 and !e.ctrlKey and !e.altKey and !e.metaKey
          e.preventDefault()
          @searchByKeyboard(e.key)

  moveHighlight: (direction) ->
    return unless @optionsContainer?.length

    options = @optionsContainer.find('.custom-select__option')

    return unless options.length

    if @highlightedIndex < 0
      @highlightedIndex = if direction > 0 then 0 else options.length - 1
    else
      @highlightedIndex += direction

      if @highlightedIndex >= options.length
        @highlightedIndex = 0

      if @highlightedIndex < 0
        @highlightedIndex = options.length - 1

    @updateHighlight(options)

  updateHighlight: (options) ->
    options.removeClass('is-highlighted')

    return if @highlightedIndex < 0

    option = options.eq(@highlightedIndex)

    return unless option.length

    option.addClass('is-highlighted')

    container = @optionsContainer[0]

    return unless container

    containerRect = container.getBoundingClientRect()
    optionRect = option[0].getBoundingClientRect()
    optionHeight = optionRect.height
    scrollOffset = optionHeight * 2

    if @highlightedIndex == 0
      container.scrollTop = 0
      return

    if @highlightedIndex == options.length - 1
      container.scrollTop = container.scrollHeight - container.clientHeight
      return

    if optionRect.top < containerRect.top + scrollOffset
      container.scrollTop -= containerRect.top + scrollOffset - optionRect.top

    else if optionRect.bottom > containerRect.bottom - scrollOffset
      container.scrollTop += optionRect.bottom - (containerRect.bottom - scrollOffset)

  selectHighlighted: ->
    return unless @optionsContainer?.length

    options = @optionsContainer.find('.custom-select__option')

    return unless options.length

    if options.length == 1
      option = options.eq(0)
      value = option.attr('data-value')

      item = @findItem(value, @getVisibleCollection())

      unless item
        item = @findItem(value, @collection)

      return unless item

      @selectValue(item)
      return

    return if @highlightedIndex < 0

    option = options.eq(@highlightedIndex)
    value = option.attr('data-value')

    item = @findItem(value, @getVisibleCollection())

    unless item
      item = @findItem(value, @collection)

    return unless item

    @selectValue(item)

  searchOptions: ->
    return unless @search

    clearTimeout(@searchTimer)
    @highlightedIndex = -1

    query = $.trim(@searchInput?.val() || '')

    if @ajax
      if query.length == 0
        @abortAjaxRequest()
        @searchCollection = []

        if @ajax.loadOnInit
          @renderCollection(@collection)
          @setWidth(@collection)
        else
          @renderCollection([])
          @setWidth()

        return

      if query.length < 3
        if @ajax.loadOnInit
          @searchCollection = []
          @renderCollection(@collection)
          @setWidth(@collection)
        else
          @searchCollection = []
          @renderCollection([])
          @setWidth()

        return

      @searchTimer = setTimeout =>
        @loadAjax(query)
      , @searchDelay

      return

    collection = @collection.filter (item) ->
      String(item.value || '').toLowerCase().includes(query.toLowerCase())

    @searchCollection = collection
    @renderCollection(collection)
    @setWidth(collection)

  scheduleQueryInputLoad: ->
    return unless @queryInputs.length
    return unless @ajax?.url

    clearTimeout(@queryInputTimer)

    @queryInputTimer = setTimeout =>
      @loadQueryInput()
    , @searchDelay

  loadInitialQueryInput: ->
    return unless @queryInputs.length
    return unless @ajax?.url

    query = @getQueryInputQuery()

    return unless query.length

    @setShimmering()
    @loadAjax(query, true, true)

  loadQueryInput: ->
    return unless @queryInputs.length
    return unless @ajax?.url

    query = @getQueryInputQuery()

    if query == @lastLoadedQuery
      if @wrapper.hasClass('is-open')
        collection = if @searchCollection.length then @searchCollection else @collection
        @renderCollection(collection)
        @setWidth(collection)

      @removeShimmering()
      return

    @highlightedIndex = -1

    if query.length == 0
      @abortAjaxRequest()
      @lastLoadedQuery = ''
      @searchCollection = []
      @renderCollection([])
      @setWidth()
      @removeShimmering()
      return

    @setShimmering()
    @loadAjax(query, true, true)

  abortAjaxRequest: ->
    return unless @ajaxRequest

    @ajaxRequest.abort()
    @ajaxRequest = null

  loadAjax: (query, render = true, selectByQueryInput = false) ->
    return unless @ajax?.url

    @abortAjaxRequest()

    @ajaxRequest = $.ajax
      url: @ajax.url
      method: @ajax.method || 'GET'
      data: $.extend({}, @ajax.data || {}, { q: query })
      dataType: 'json'

      success: (response) =>
        collection = if @ajax.getCollection
          @ajax.getCollection(response)
        else
          response.collection || response

        collection = @normalizeCollection(collection || [])

        @lastLoadedQuery = query

        if query == ''
          @collection = collection
          @searchCollection = []
        else
          @searchCollection = collection
          @mergeCollection(collection)

        @highlightedIndex = -1

        @syncSelectedOptions()
        @syncValue()

        if render
          visibleCollection = if query == ''
            @collection
          else
            @searchCollection

          @renderCollection(visibleCollection)
          @setWidth(visibleCollection)

        if selectByQueryInput
          @selectFirstQueryInputResult()

        @setInitialized() if query == ''

        @removeShimmering() if selectByQueryInput

      error: (xhr, status) =>
        return if status == 'abort'

        @searchCollection = [] if query != ''
        @highlightedIndex = -1

        @renderCollection([]) if render
        @setWidth()

        @setInitialized() if query == ''

        @removeShimmering() if selectByQueryInput

      complete: =>
        @ajaxRequest = null

  mergeCollection: (collection) ->
    collection.forEach (item) =>
      existingIndex = @collection.findIndex (collectionItem) ->
        String(collectionItem.key) == String(item.key)

      if existingIndex >= 0
        @collection[existingIndex] = item
      else
        @collection.push(item)

  selectFirstQueryInputResult: ->
    return unless @searchCollection?.length

    selectedValues = @select.val() || []

    selectedValues = [selectedValues] unless $.isArray(selectedValues)

    selectedValues = selectedValues.filter (value) ->
      String(value).length > 0

    selectedItem = null

    selectedValues.some (value) =>
      selectedItem = @searchCollection.find (item) ->
        String(item.key) == String(value)

      !!selectedItem

    if selectedItem
      @ensureOption(selectedItem)
      @mergeCollection([selectedItem])
      @syncValue()

      if @wrapper.hasClass('is-open')
        @renderCollection(@searchCollection)
        @setWidth(@searchCollection)

      return

    firstItem = @searchCollection[0]

    return unless firstItem

    if @multiple
      @ensureOption(firstItem)

      @select.val([String(firstItem.key)])
      @select.trigger('change')

      return

    @selectValue(firstItem)

  loadSelectedAjax: ->
    return unless @ajax?.url

    selectedValues = @select.val() || []

    selectedValues = [selectedValues] unless $.isArray(selectedValues)

    selectedValues = selectedValues.filter (value) ->
      String(value).length > 0

    unless selectedValues.length
      @loadInitialQueryInput()
      return

    requestsCount = selectedValues.length
    completedRequests = 0

    selectedValues.forEach (value) =>
      option = @select.find('option').filter ->
        String($(this).val()) == String(value)
      .first()

      unless option.length
        completedRequests += 1
        @setInitialized() if completedRequests == requestsCount
        return

      query = $.trim(option.text())

      @loadSelectedValueAjax(query, value, =>
        completedRequests += 1

        if completedRequests == requestsCount
          @setInitialized()
      )

  loadSelectedValueAjax: (query, value, completeCallback) ->
    return unless @ajax?.url

    $.ajax
      url: @ajax.url
      method: @ajax.method || 'GET'
      data: $.extend({}, @ajax.data || {}, { q: query })
      dataType: 'json'

      success: (response) =>
        collection = if @ajax.getCollection
          @ajax.getCollection(response)
        else
          response.collection || response

        collection = @normalizeCollection(collection || [])

        @mergeCollection(collection)

        item = collection.find (collectionItem) ->
          String(collectionItem.key) == String(value)

        if item
          @ensureOption(item)
          @mergeCollection([item])

        @syncValue()
        @setWidth()

      error: (xhr, status) =>
        return if status == 'abort'

        @syncValue()
        @setWidth()

      complete: =>
        completeCallback()

  renderOptions: ->
    collection = []

    unless @ajax
      @select.find('option').each (index, option) ->
        $option = $(option)

        collection.push
          key: $option.val()
          value: $option.text()
          color: $option.attr('data-color')
          icon:
            icon_class: $option.attr('data-icon-class')
            icon_color_class: $option.attr('data-icon-color-class')
            icon_color: $option.attr('data-icon-color')
            icon_title: $option.attr('data-icon-title')
            icon_value: $option.attr('data-icon-value')
            icon_url: $option.attr('data-icon-url')
          class: $option.attr('data-class')

      @collection = @normalizeCollection(collection)
      @searchCollection = []
      @renderCollection(@collection)

      return

    @collection = []
    @searchCollection = []

  normalizeCollection: (collection) ->
    collection.map (item) ->
      icon = item.icon || {}

      {
        key: item.key
        value: item.value
        description: item.description || null
        color: item.color || item.data_color || item['data-color'] || null
        icon:
          icon_class: icon.icon_class || null
          icon_color_class: icon.icon_color_class || null
          icon_color: icon.icon_color || null
          icon_value: icon.icon_value || null
          icon_text: icon.icon_text || null
          icon_title: icon.icon_title || null
          icon_url: icon.icon_url || icon.url || null
        class: item.class || item.css_class || item.data_class || item['data-class'] || null
      }

  syncDisabled: ->
    @wrapper.toggleClass('disabled', @select.prop('disabled') || @select.hasClass('disabled'))

  syncSelectedOptions: ->
    selectedValues = @select.val() || []

    selectedValues = [selectedValues] unless $.isArray(selectedValues)

    selectedValues = selectedValues.map(String)

    @optionsContainer?.find('.custom-select__option').each ->
      $option = $(this)
      optionValue = $option.attr('data-value')
      isSelected = selectedValues.includes(String(optionValue))

      $option.toggleClass('selected', isSelected)

      check = $option.find('.custom-select__option-check').first()

      if isSelected
        unless check.length
          $option.append('<span class="ph ph-check custom-select__option-check"></span>')
      else
        check.remove()

    selectedValues.forEach (value) =>
      item = @collection.find (collectionItem) ->
        String(collectionItem.key) == String(value)

      @ensureOption(item) if item

  getVisibleCollection: ->
    return @collection unless @ajax

    if @queryInputs.length
      return @searchCollection if @searchCollection.length
      return @collection

    if @searchInput?.val().length >= 3
      return @searchCollection
    else if @ajax.loadOnInit
      return @collection
    else
      return @searchCollection

  renderCollection: (collection) ->
    @optionsContainer?.remove()
    @optionsContainer = null
    @highlightedIndex = -1

    return unless collection?.length

    @optionsContainer = $('<div class="custom-select__options"></div>')

    collection.forEach (item) =>
      @renderOption(item)

    @dropdown.append(@optionsContainer)

    query = if @queryInputs.length
      @getQueryInputQuery()
    else
      $.trim(@searchInput?.val())

    if collection.length == 1 and query.length >= 3
      @highlightedIndex = 0
      @optionsContainer.find('.custom-select__option').first().addClass('is-highlighted')

  renderOption: (item) ->
    return unless @optionsContainer

    option = $('<div class="custom-select__option"></div>')

    option.attr('data-value', item.key)
    option.addClass('prompt') if String(item.key) == ''

    selectedValues = @select.val() || []
    selectedValues = [selectedValues] unless $.isArray(selectedValues)

    isSelected = selectedValues.map(String).includes(String(item.key))

    option.addClass('selected') if isSelected

    if item.class
      option.addClass(item.class)

    if item.color
      option.attr('style', "--#{item.class}: #{item.color};")

    content = @renderContent(item, 'custom-select__option-content')

    content.removeClass(item.class) if item.class
    content.removeAttr('style')

    option.append(content)

    if @multiple and isSelected
      option.append('<span class="ph ph-check custom-select__option-check"></span>')

    option.on 'mouseenter.customSelect', (e) =>
      options = @optionsContainer?.find('.custom-select__option')

      return unless options?.length

      @highlightedIndex = options.index(option)

      options.removeClass('is-highlighted')
      option.addClass('is-highlighted')

    option.on 'mouseleave.customSelect', (e) =>
      option.removeClass('is-highlighted')
      @highlightedIndex = -1

    option.on 'click.customSelect', (e) =>
      e.preventDefault()
      e.stopPropagation()

      @selectValue(item)

    @optionsContainer.append(option)

  renderContent: (item, baseClass) ->
    content = $('<span></span>')

    content.addClass(baseClass) if baseClass

    if item.icon?.icon_url
      icon = $('<img>')

      icon.addClass('option-icon')
      icon.addClass(item.icon.icon_class) if item.icon.icon_class
      icon.attr('src', item.icon.icon_url)
      icon.attr('alt', '')
      icon.attr('loading', 'lazy')

      if item.icon.icon_color_class
        icon.addClass(item.icon.icon_color_class)

        if item.icon.icon_color
          icon.attr('style', "--#{item.icon.icon_color_class}: #{item.icon.icon_color};")

      if item.icon.icon_title
        icon.attr('data-tooltip', item.icon.icon_title)

      content.append(icon)

    else if item.icon?.icon_class or item.icon?.icon_text or item.icon?.icon_value
      icon = $('<span></span>')

      icon.addClass('option-icon')
      icon.addClass(item.icon.icon_class) if item.icon.icon_class

      if item.icon.icon_color_class
        icon.addClass(item.icon.icon_color_class)

        if item.icon.icon_color
          icon.attr('style', "--#{item.icon.icon_color_class}: #{item.icon.icon_color};")

      if item.icon.icon_title
        icon.attr('data-tooltip', item.icon.icon_title)

      if item.icon.icon_text
        icon.text(item.icon.icon_text)
      else if item.icon.icon_value
        icon.text(item.icon.icon_value)

      content.append(icon)

    info = $('<span class="custom-select__option-info"></span>')

    text = $('<span></span>')
    text.addClass("#{baseClass}-text") if baseClass
    text.html(item.value)

    info.append(text)

    if item.description
      description = $('<span></span>')
      description.addClass("#{baseClass}-description") if baseClass
      description.html(item.description)
      info.append(description)

    content.append(info)

    content

  selectValue: (item) ->
    @mergeCollection([item])

    if @multiple
      values = @select.val() || []

      values = [values] unless $.isArray(values)

      values = values.map (value) ->
        String(value)

      itemValue = String(item.key)

      if values.includes(itemValue)
        values = values.filter (value) ->
          value != itemValue
      else
        values.push(itemValue)

      @ensureOption(item)
      @select.val(values)

      @select.trigger('change')

      @syncSelectedOptions()

      if @wrapper.hasClass('is-open')
        @renderCollection(@getVisibleCollection())
        @setWidth(@getVisibleCollection())

      return

    @ensureOption(item)
    @select.val(String(item.key))
    @select.trigger('change')

    @searchInput?.val('')

    unless @queryInputs.length
      @searchCollection = []

    @highlightedIndex = -1

    @close()

  clearValue: (value) ->
    if @multiple
      values = @select.val() || []

      values = [values] unless $.isArray(values)

      values = values.filter (currentValue) ->
        String(currentValue) != String(value)

      @select.val(values)
    else
      @select.val('')

    @syncSelectedOptions()
    @select.trigger('change')

    if @multiple and @wrapper.hasClass('is-open')
      @renderCollection(@getVisibleCollection())
      @setWidth(@getVisibleCollection())

  ensureOption: (item) ->
    return unless item

    existing = @select.find('option').filter ->
      String($(this).val()) == String(item.key)
    .first()

    if existing.length
      existing.text(item.value)

      if item.color
        existing.attr('data-color', item.color)
      else
        existing.removeAttr('data-color')

      if item.icon
        existing.attr('data-icon-class', item.icon.icon_class) if item.icon.icon_class
        existing.attr('data-icon-color-class', item.icon.icon_color_class) if item.icon.icon_color_class
        existing.attr('data-icon-color', item.icon.icon_color) if item.icon.icon_color
        existing.attr('data-icon-title', item.icon.icon_title) if item.icon.icon_title
        existing.attr('data-icon-value', item.icon.icon_value) if item.icon.icon_value
        existing.attr('data-icon-url', item.icon.icon_url) if item.icon.icon_url
      else
        existing.removeAttr('data-icon-class')
        existing.removeAttr('data-icon-color-class')
        existing.removeAttr('data-icon-color')
        existing.removeAttr('data-icon-title')
        existing.removeAttr('data-icon-value')
        existing.removeAttr('data-icon-url')

      if item.class
        existing.attr('data-class', item.class)
      else
        existing.removeAttr('data-class')

      return

    option = $('<option></option>')

    option.attr('value', item.key)
    option.text(item.value)

    option.attr('data-color', item.color) if item.color

    if item.icon
      option.attr('data-icon-class', item.icon.icon_class) if item.icon.icon_class
      option.attr('data-icon-color-class', item.icon.icon_color_class) if item.icon.icon_color_class
      option.attr('data-icon-color', item.icon.icon_color) if item.icon.icon_color
      option.attr('data-icon-title', item.icon.icon_title) if item.icon.icon_title
      option.attr('data-icon-value', item.icon.icon_value) if item.icon.icon_value
      option.attr('data-icon-url', item.icon.icon_url) if item.icon.icon_url

    option.attr('data-class', item.class) if item.class

    @select.append(option)

  syncValue: ->
    values = @select.val()

    if @multiple
      values = values || []
      values = [values] unless $.isArray(values)

      if values.length
        @renderSelected(values)
      else
        @renderPrompt()
    else
      if values
        @renderSelected([values])
      else
        @renderPrompt()

  renderPrompt: ->
    @value.empty()

    prompt = $('<span class="custom-select__prompt"></span>')

    prompt.text(@prompt)

    @value.append(prompt)

  renderSelected: (values) ->
    @value.empty()

    values.forEach (value) =>
      option = @select.find('option').filter ->
        String($(this).val()) == String(value)
      .first()

      return unless option.length

      item = @collection.find (collectionItem) ->
        String(collectionItem.key) == String(value)

      unless item
        item =
          key: option.val()
          value: option.text()
          color: option.attr('data-color')
          icon:
            icon_class: option.attr('data-icon-class')
            icon_color_class: option.attr('data-icon-color-class')
            icon_color: option.attr('data-icon-color')
            icon_title: option.attr('data-icon-title')
            icon_value: option.attr('data-icon-value')
            icon_url: option.attr('data-icon-url')
          class: option.attr('data-class')

      selected = $('<span class="custom-select__selected"></span>')
      selected.addClass(item.class) if item.class

      if item.color and item.class
        selected.attr('style', "--#{item.class}: #{item.color};")

      content = @renderContent(item, 'custom-select__selected-content')

      selected.attr('data-value', item.key)

      close = $('<span class="ph ph-x ph-x custom-select__selected-remove"></span>')

      close.on 'click.customSelect', (e) =>
        e.preventDefault()
        e.stopPropagation()

        @clearValue(item.key)

      selected.append(content)
      selected.append(close)

      @value.append(selected)

  setWidth: (visibleCollection = null) ->
    return if @maxWidth == false

    if @width
      width = if typeof @width == 'number' then "#{@width}px" else @width

      @wrapper.css
        width: width
        maxWidth: width

      return

    if @maxWidth
      width = parseFloat(@maxWidth)

      @wrapper.css
        width: "#{Math.ceil(width)}px"
        maxWidth: "#{Math.ceil(width)}px"

      return

    canvas = document.createElement('canvas')
    context = canvas.getContext('2d')
    context.font = @control.css('font')

    selectedValues = @select.val() || []
    selectedValues = [selectedValues] unless $.isArray(selectedValues)

    if !selectedValues.length and !visibleCollection?.length
      @wrapper.css
        width: ''
        maxWidth: 'none'

      return

    width = 0

    selectedValues.forEach (value) =>
      option = @select.find('option').filter ->
        String($(this).val()) == String(value)
      .first()

      return unless option.length

      item = @findItem(value, @collection)

      unless item
        item =
          key: option.val()
          value: option.text()
          color: option.attr('data-color')
          icon:
            icon_class: option.attr('data-icon-class')
            icon_color_class: option.attr('data-icon-color-class')
            icon_color: option.attr('data-icon-color')
            icon_title: option.attr('data-icon-title')
            icon_value: option.attr('data-icon-value')
            icon_url: option.attr('data-icon-url')
          class: option.attr('data-class')

      measuredWidth = context.measureText(String(item.value || '')).width

      if item.icon?.icon_class or item.icon?.icon_url
        icon = @value.find(".custom-select__selected[data-value='#{value}'] .option-icon").first()

        measuredWidth += (icon.outerWidth(true) + 5) if icon.length

      width = measuredWidth if measuredWidth > width

    if !selectedValues.length
      width = context.measureText(@prompt || '').width

    visibleCollection?.forEach (item) =>
      measuredWidth = context.measureText(String(item.value || '')).width

      option = @optionsContainer?.find(".custom-select__option[data-value='#{item.key}']").first()

      if option?.length
        icon = option.find('.option-icon').first()

        measuredWidth += (icon.outerWidth(true) + 5) if icon.length

      width = measuredWidth if measuredWidth > width

    width += 40

    minWidth = parseFloat(@options.minWidth || 0)
    width = minWidth if width < minWidth

    @wrapper.css
      width: "#{Math.ceil(width)}px"
      maxWidth: 'none'

  findItem: (value, collection = null) ->
    return null unless collection?.length

    collection.find (collectionItem) ->
      String(collectionItem.key) == String(value)

  refresh: ->
    @multiple = @select.prop('multiple')

    if @ajax
      @syncValue()
      @syncSelectedOptions()

      if @wrapper.hasClass('is-open')
        collection = @getVisibleCollection()

        @renderCollection(collection)
        @setWidth(collection)
      else
        @setWidth()

      return

    collection = []

    @select.find('option').each (index, option) ->
      $option = $(option)

      collection.push
        key: $option.val()
        value: $option.text()
        color: $option.attr('data-color')
        icon:
          icon_class: $option.attr('data-icon-class')
          icon_color_class: $option.attr('data-icon-color-class')
          icon_color: $option.attr('data-icon-color')
          icon_title: $option.attr('data-icon-title')
          icon_value: $option.attr('data-icon-value')
          icon_url: $option.attr('data-icon-url')
        class: $option.attr('data-class')

    @collection = @normalizeCollection(collection)
    @searchCollection = []

    @syncValue()

    if @wrapper.hasClass('is-open')
      @renderCollection(@collection)
      @setWidth(@collection)
    else
      @setWidth()

  destroy: ->
    clearTimeout(@searchTimer)
    clearTimeout(@queryInputTimer)
    clearTimeout(@keyboardSearchTimer)

    @abortAjaxRequest()

    $(document).off ".#{@instanceId}"

    @queryInputs.forEach (input) =>
      $(input).off ".#{@instanceId}"

    @control.off '.customSelect'
    @searchInput?.off '.customSelect'
    @select.off '.customSelect'
    @dropdown.off '.customSelect'
    @optionsContainer?.off '.customSelect'

    @optionsContainer?.remove()

    @wrapper.remove()

    @select.removeClass('custom-select-native')
    @select.removeData('customSelect')

CustomSelect.instanceCount = 0

$.fn.customSelect = (options = {}) ->
  @each ->
    select = $(@)
    instance = select.data('customSelect')

    if instance
      instance.options = $.extend(true, instance.options, options)
      instance.refresh()
      return

    instance = new CustomSelect(select, options)

    select.data('customSelect', instance)

  @