module ApplicationHelper
  include TranslateHelper
  
  def product_main_image(product, class_name = nil)
    image = if product&.main_image_id.present?
      product.images.find { |img| img.blob_id == product.main_image_id } || product.images.first
    else
      product.images.first
    end

    content_tag(:div, class: "product-image-wrapper #{class_name} #{'no-image' unless image}") do
      if image
        image_tag image, class: 'product-image'
      else
        ph_duotone_icon(:package)
      end
    end
  end

  def image_tag_from_url(url, **options)
    return if url.blank?

    image_tag(url, **options)
  end

  def copy_clipboard_toastr(text)
    content_tag(:span, class: 'copy-text', data: { message: tgm(:clipboard), description: tgm(:text_copied), tooltip: tgm(:copy) }) do
      concat(text)
      concat(ph_duotone_icon(:copy))
    end
  end

  def toastr_flash(options = {})
    flash.map do |type, flash_description|
      method = case type.to_sym
      when :notice, :primary then "primary"
      when :alert, :error, :danger then "danger"
      when :warning then "warning"
      when :success then "success"
      else "primary"
      end

      options = options.symbolize_keys

      if flash_description.is_a?(Hash)
        flash_options = flash_description.symbolize_keys
        flash_options[:message] = options[:message] if options[:message].present?
        flash_options[:details] = options[:details] if options[:details].present?
        flash_options[:life_time] = options[:life_time] if options[:life_time].present?
        flash_options[:position] = options[:position] if options[:position].present?
      else
        flash_options = {
          description: flash_description,
          message: options[:message],
          details: options[:details],
          life_time: options[:life_time],
          position: options[:position]
        }.compact
      end

      "toastr.#{method}(#{flash_options.to_json});"
    end.join("\n").html_safe
  end

  def toastr_message(type, message)
    message.presence || tgm("#{type}")
  end

  def disable_with_icon class_name=''
    ph_bold_icon(:spinner, "spin #{class_name}")
  end

  def ph_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, nil, class: "ph ph-#{icon_name.to_s.tr("_", "-")} #{class_name}")
  end

  def ph_bold_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, nil, class: "ph ph-bold ph-#{icon_name.to_s.tr("_", "-")} #{class_name}")
  end

  def ph_thin_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, nil, class: "ph ph-thin ph-#{icon_name.to_s.tr("_", "-")} #{class_name}")
  end

  def ph_fill_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, nil, class: "ph ph-fill ph-#{icon_name.to_s.tr("_", "-")} #{class_name}")
  end

  def ph_duotone_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, nil, class: "ph ph-duotone ph-#{icon_name.to_s.tr("_", "-")} #{class_name}")
  end
  
  def ph_icon_by_style(icon_name, icon_style = :default, class_name = '')
    icon_methods = { default: :ph_icon, bold: :ph_bold_icon, thin: :ph_thin_icon, fill: :ph_fill_icon, duotone: :ph_duotone_icon }
    send(icon_methods.fetch(icon_style.to_s.to_sym, :ph_icon), icon_name, class_name)
  end

  def g_icon icon_name='', class_name=''
    return '' unless icon_name
    content_tag(:span, icon_name, class: "material-symbols-outlined g-icon #{class_name}")
  end
  
  def owner_icon class_name=''
    content_tag(:span, 'owner', class: "color-badge-primary owner-icon #{class_name}")
  end

  def color_badge(text = nil, color = nil)
    content_tag(:span, text, class: "color-badge", style: "--color-badge: #{color}; color: #{color};")
  end
  
  def render_popup(partial, locals = {})
    render partial: partial, locals: locals
  end

  def comment_icon(comment)
    return nil unless comment.present?

    content_tag(:span, class: "flex", data: { tooltip: comment }) do
      ph_duotone_icon(:chat_centered_text, 'text-primary')
    end
  end

  def paid_status_class(source)
    return 'color-badge-warning' if source.income_operation.present?
    return 'color-badge-success' if source.expense_operation.present? && source.expense_paid?
    return 'color-badge-warning' if source.expense_operation.present? && source.expense_operation.paid_amount.to_f > 0

    'color-badge-danger'
  end

  def popup(id:, position: :left, title: '', icon: :dots_three, class_name: '', tooltip: nil, icon_style: :bold, &block)
    content = capture(&block)
    render 'shared/popup_buttons', id: id, position: position, content: content, icon: icon, icon_style: icon_style, tooltip: tooltip, class_name: class_name, title: title
  end

  def financial_indicator_badge(number)
    return '' unless number

    number = number.to_f

    case number
    when 0
      bg = 'grey'
      color = '#000'
    when ->(n) { n > 0 }
      bg = 'hover-success'
      color = '#fff'
    else
      bg = 'hover-danger'
      color = '#fff'
    end

    content_tag(:span, number, class: "color-badge", style: "background: var(--#{bg}); color: #{color};")
  end

  def current_page_name
    if @cur_url.include?('users')
      tm(User, :title)
    elsif @cur_url.include?('clients')
      tm(Client, :title)
    elsif @cur_url.include?('orders')
      tm(Order, :title)
    elsif @cur_url.include?('interactions')
      tm(Interaction, :title)
    else
      tm(Client, :title)
    end
  end

  def pretty_date(date)
    date.strftime("%d %B %Y") if date.present?
  end

  def pretty_date_month_year(date)
    date.strftime("%B %Y") if date.present?
  end

  def pretty_number(number, delimiter = '')
    number_to_currency number, precision: 0, delimiter: delimiter, unit: ""
  end

  def pretty_decimal(number, separator = '.', delimiter = '')
    # Используем NumberHelper через ActionView::Helpers::NumberHelper
    ActionController::Base.helpers.number_to_currency(number, precision: 2, delimiter: delimiter, unit: "", separator: separator)
  end

  def pretty_date_time(date)
    date.strftime("%d %B %Y %H:%M") if date.present?
  end

  def small_date(date)
    date.strftime("%d.%m.%Y") if date.present?
  end

  def small_date_hyphen(date)
    date.strftime("%d-%m-%Y") if date.present?
  end

  def time_only(date)
    date.strftime("%H:%M") if date.present?
  end

  def smallest_date(date)
    date.strftime("%d.%m") if date.present?
  end

  def small_datetime(date)
    date.strftime("%d.%m.%Y %H:%M") if date.present?
  end

  def compact_date(date)
    return unless date.present?

    format = date.year == Date.current.year ? '%-d %b' : '%-d %b %Y'
    I18n.l(date, format: format)
  end

  def compact_datetime(date)
    return unless date.present?

    format = date.year == Date.current.year ? '%-d %b, %H:%M' : '%-d %b %Y, %H:%M'
    I18n.l(date, format: format)
  end
  
  def compact_duration(start_date, end_date)
    return unless start_date.present? && end_date.present?

    compact_duration_from_seconds(end_date - start_date)
  end

  def compact_duration_from_seconds(seconds)
    return unless seconds.present?

    seconds = seconds.to_f

    if seconds > 1.day
      days = (seconds / 1.day).floor
      hours = ((seconds % 1.day) / 1.hour).floor
      minutes = ((seconds % 1.hour) / 1.minute).floor

      values = [
        [days, I18n.t('helpers.compact_duration.day_short')],
        [hours, I18n.t('helpers.compact_duration.hour_short')],
        [minutes, I18n.t('helpers.compact_duration.minute_short')]
      ]
    else
      hours = (seconds / 1.hour).floor
      minutes = ((seconds % 1.hour) / 1.minute).floor
      seconds = (seconds % 1.minute).round(2)

      values = [
        [hours, I18n.t('helpers.compact_duration.hour_short')],
        [minutes, I18n.t('helpers.compact_duration.minute_short')],
        [seconds, I18n.t('helpers.compact_duration.second_short')]
      ]
    end

    values
      .reject { |value, _| value.zero? }
      .map { |value, unit| "#{value}#{unit}" }
      .join(' ')
  end

  def format_number(number, precision: 2, delimiter: ',', separator: '.')
    number_with_precision(
      number,
      precision: precision,
      delimiter: delimiter,
      separator: separator
    )
  end

  def logo_icon
    image_tag "/icons/vexodus_mini.png"
  end

  def normalize_url(value)
    return unless value.present?

    value.start_with?('http://', 'https://') ? value : "https://#{value}"
  end


  def active_sidebar?(url_path)
    url_path.include?("/#{@cur_url}") || url_path == @cur_url
  end

  private

  def contrast_color(hex)
    return '#000000' unless hex.present?

    hex = hex.delete('#')

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    brightness = ((r * 299) + (g * 587) + (b * 114)) / 1000

    brightness > 160 ? '#000000' : '#ffffff'
  end

end
