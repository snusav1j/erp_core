module UserHelper
  def user_image(user: nil, class_name: nil, title: false)
    user ||= current_user

    classes = ['user-icon', class_name].compact.join(' ')
    tooltip = title ? user.fullname : nil

    if user.user_image.attached?
      content_tag(:div, class: classes, data: { tooltip: tooltip }) do
        image_tag(url_for(user.user_image))
      end
    else
      content_tag(:div, class: classes, data: { tooltip: tooltip }) do
        user.initials
      end
    end
  end
end
