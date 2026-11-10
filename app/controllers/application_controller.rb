class ApplicationController < ActionController::Base
  before_action :set_paper_trail_whodunnit
  include Pundit::Authorization
  include ActionView::Helpers::NumberHelper

  include ApplicationHelper

  # include BreadcrumbsHelper
  # helper BreadcrumbsHelper
  
  helper_method :currency_logo_url
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :authenticate_user!
  before_action :check_user_banned, unless: :devise_controller?
  before_action :update_last_seen_at, if: :user_signed_in?
  before_action :set_global_vars

  # before_action :setup_breadcrumbs

  after_action :save_last_page

  def root
    redirect_to session[:last_page].presence
  end

  def format_money(amount, currency_symbol = "")
    negative = amount.to_f.negative?
    integer, fractional = format("%.2f", amount.to_f.abs).split(".")

    sign = negative ? '<span class="text-danger">-</span>' : ''

    "<span class=\"money\">#{sign}<span class=\"money-symbol\">#{currency_symbol}</span>#{number_with_delimiter(integer, delimiter: ",")}<span class=\"money-cents\">.#{fractional}</span></span>".html_safe
  end

  def human_money(amount, currency_symbol = "")
    negative = amount.to_f.negative?
    result = number_to_human(amount.to_f.abs, units: { thousand: tgm(:thousand), million: tgm(:million), billion: tgm(:billion), trillion: tgm(:trillion) }, separator: ",", delimiter: " ", precision: 2, strip_insignificant_zeros: true)
    integer, fractional = result.split(",", 2)
    sign = negative ? '<span class="text-danger">-</span>' : ''
    symbol = currency_symbol.present? ? "<span class=\"money-symbol\">#{currency_symbol}</span>" : ""

    if fractional
      "<span class=\"money\">#{sign}#{integer},<span class=\"money-cents\">#{fractional}</span>#{symbol}</span>".html_safe
    else
      "<span class=\"money\">#{sign}#{integer}#{symbol}</span>".html_safe
    end
  end

  def set_global_vars
    @http_host = "#{request.protocol}#{request.host_with_port}"
    @cur_url = request.original_fullpath
    @ref_url = request.referer

    @http_address = "#{@http_host}/#{@cur_url}"
  end

  def get_val_from_params name
    val = nil

    if name.is_a?(Array)
      val = params

      while val.is_a?(Hash)
        name.each do |key|
          val = val[key] if val
        end
      end
    else
      val = params[name]
    end

    val
  end

  def param_i name, default_value=nil
    val = self.get_val_from_params name

    val.present? && val.to_i > 0 ? h(val).to_i : default_value
  end

  def param_a name, default_value=[]
    res = default_value
    vals = self.get_val_from_params name

    if vals.present?
      vals.each do |val|
        res << h(val).to_i if val.to_i > 0
      end
    end

    res
  end

  def param_dec name, default_value=nil
    val = self.get_val_from_params name

    return default_value if !val

    val = val.gsub(',', '.')

    val.present? && val.to_d > 0 ? h(val).to_d : default_value
  end

  def param_f name, default_value=nil
    val = self.get_val_from_params name

    return default_value if !val

    val = val.gsub(',', '.')

    val.present? && val.to_f > 0 ? h(val).to_f : default_value
  end

  def param_b name, default_value=nil
    val = self.get_val_from_params name
    res = default_value

    res = true if val == "true" || val == '1'
    res = false if val == "false" || val == '0'

    res
  end

  def param_s name, default_value=nil
    val = self.get_val_from_params name

    val.present? ? h(val.strip) : default_value
  end

  def param_d name, default_value=nil
    val = self.get_val_from_params name

    val.present? ? h(val).to_date : default_value
  end

  def param_dt name, default_value=nil
    val = self.get_val_from_params name

    val.present? ? h(val).to_datetime : default_value
  end

  def param_sym name, default_value=false
    params[name].blank? ? default_value : h(params[name]).to_sym
  end

  def param_ar name, default_value=[]
    params[name].present? ? params[name].to_a : default_value
  end

  def save_with_toastr(record)
    result = record.save

    flash.now[:danger] = { description: record.errors.full_messages.join(', ') } unless result

    result
  rescue StandardError => e
    flash.now[:danger] = { description: e.message }
    false
  end

  def update_with_toastr(record, attributes)
    result = record.update(attributes)

    flash.now[:danger] = { description: record.errors.full_messages.join(', ') } unless result

    result
  rescue StandardError => e
    flash.now[:danger] = { description: e.message }
    false
  end

  def destroy_with_toastr(record)
    result = record.destroy

    flash.now[:danger] = { description: record.errors.full_messages.join(', ') } unless result

    result
  rescue StandardError => e
    flash.now[:danger] = { description: e.message }
    false
  end


  private

  def setup_breadcrumbs
    return unless controller_path.split("/").length == 1
    return unless %w[index show new edit].include?(action_name)

    setup_crud_breadcrumbs
  end

  def check_user_banned
    return unless current_user

    user_banned = current_user.banned?

    alert_msg =
      if user_banned
        tm(User, :access_denied)
      elsif user_banned
        tm(User, :banned)
      else
        tm(User, :error_contact_administrator)
      end

    if user_banned
      sign_out current_user
      redirect_to new_user_session_path, alert: alert_msg
    end
  end

  def user_not_authorized
    if request.format.js?
      render json: { error: tgm(:access_denied) }, status: :forbidden
    else
      flash[:danger] = { description: tgm(:access_denied) }
      redirect_to user_path(current_user)
    end
  end
  
  def update_last_seen_at
    return if current_user.banned?
    return if current_user.last_seen_at.present? && current_user.last_seen_at > 5.minutes.ago

    current_user.update_column(:last_seen_at, Time.current)
  end
  
  def record_not_found
    flash[:danger] = { description: tgm(:record_not_found) }
    redirect_to request.path.split('/')[0..1].join('/')
  end

  def save_last_page
    return unless current_user.present?
    return unless request.get?
    return unless request.format.html?
    return if request.path == root_path
    return if response.redirect?

    session[:last_page] = request.fullpath
  end
end