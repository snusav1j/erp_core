module TranslateHelper
  def tgm(key, options = {})
    text = I18n.t("global.#{key.to_s}", **options)
    sanitize(text)
  end

  def tn(key, options = {})
    text = I18n.t("global.notice.#{key.to_s}", **options)
    sanitize(text)
  end

  def tm(model, key, options = {})
    model_key = extract_model_key(model)
    text = I18n.t("activerecord.attributes.#{model_key}.#{key.to_s}", **options)
    sanitize(text)
  end

  def ta(model, attr_name, options = {})
    tm(model, attr_name, options)
  end

  def ts(key)
    t("sidebar.groups.#{key}")
  end

  def t_model(model)
    model_key = extract_model_key(model)
    I18n.t("activerecord.models.#{model_key}", default: model_key.to_s.humanize)
  end

  def tc(key, options = {})
    I18n.t("controller.#{controller.controller_name}.#{key}", **options)
  end
  
  private

  def sanitize(text)
    ActionController::Base.helpers.sanitize(text.to_s)
  end

  def extract_model_key(model)
    case model
    when Class
      model.model_name.i18n_key
    when ActiveRecord::Base
      model.model_name.i18n_key
    when Symbol, String
      model.to_s.underscore.to_sym
    else
      raise ArgumentError, "Cannot extract model key from #{model.inspect}"
    end
  end
end