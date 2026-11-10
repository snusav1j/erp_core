class Version < PaperTrail::Version
  self.table_name = "versions"

  def event_translation_key
    if create? || destroy?
      case item_type
      when "PurchaseItem", "OrderItem"
        "event_#{item_type.downcase}_#{event_name}_record"

      when "StockMovement"
        operation_type = changeset["operation_type"]&.last
        "event_stockmovement_#{event_name}_record_#{operation_type}"

      else
        "event_#{event_name}_record"
      end
    else
      if changeset.length > 1
        case item_type
        when "PurchaseItem", "OrderItem"
          "event_#{item_type.downcase}_#{event_name}_record"

        when "StockMovement"
          "event_stockmovement_#{event_name}_record"

        else
          "event_#{event_name}_record"
        end
      else
        "event_#{event_name}"
      end
    end
  end

  def user
    User.find_by(id: self.whodunnit)
  end

  def event_name
    I18n.t("paper_trail.events.#{self.event}", default: self.event)
  end

  def item_type_name
    I18n.t("activerecord.models.#{self.item_type.underscore}", default: self.item_type)
  end

  def show_changes?
    %w[create destroy].include?(self.event)
  end

  def changes_text
    case self.event
    when "create"
      I18n.t("paper_trail.changes.created")
    when "destroy"
      I18n.t("paper_trail.changes.destroyed")
    when "update"
      self.update_data
    else
      self.event_name
    end
  end

  def full_changes_text
    case self.event
    when "create"
      self.created_data
    when "destroy"
      self.destroyed_data
    when "update"
      self.update_data
    end
  end

  def changeset
    YAML.safe_load(
      self.object_changes || "{}",
      permitted_classes: [
        Symbol,
        Time,
        Date,
        ActiveSupport::TimeWithZone
      ]
    ) || {}
  end

  def create?
    self.event == "create"
  end

  def update?
    self.event == "update"
  end

  def destroy?
    self.event == "destroy"
  end

  def downcase_attribute_name(attribute)
    "#{self.attribute_name(attribute)}".downcase
  end

  def update_data
    self.changeset.map do |attribute, values|
      old_value, new_value = values

      "#{self.attribute_name(attribute)}: #{old_value} → #{new_value}"
    end.join("\n")
  end

  def created_data
    self.object_data.map do |attribute, value|
      "#{self.attribute_name(attribute)}: #{value}"
    end.join("\n")
  end

  def destroyed_data
    self.object_data.map do |attribute, value|
      "#{self.attribute_name(attribute)}: #{value}"
    end.join("\n")
  end

  def object_data
    YAML.safe_load(
      self.object || "{}",
      permitted_classes: [
        Symbol,
        Time,
        Date,
        ActiveSupport::TimeWithZone
      ]
    ) || {}
  end

  def attribute_name(attribute)
    if item_type == "CustomFieldValue" && attribute.to_s == "value"
      item&.custom_field&.label || attribute.humanize
    else
      I18n.t(
        "activerecord.attributes.#{item_type.underscore}.#{attribute}",
        default: attribute.humanize
      )
    end
  end

  def self.display_value(record_class, attribute, value)
    return I18n.t("global.yes") if value == true
    return I18n.t("global.no") if value == false
    return if value.blank?

    attribute = attribute.to_s

    if value.is_a?(Date) || value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return I18n.l(value, format: "%d.%m.%Y %H:%M")
    end

    if value.is_a?(String)
      begin
        date = Time.zone.parse(value)

        if value.match?(/\A\d{4}-\d{2}-\d{2}T/)
          return I18n.l(date, format: "%d.%m.%Y %H:%M")
        end
      rescue ArgumentError
      end
    end

    enum_values = record_class.send(attribute.pluralize) if record_class.respond_to?(attribute.pluralize)

    if enum_values.is_a?(Hash)
      key = enum_values.key(value.to_i)

      scope = attribute == "operation_type" ? "operations" : "statuses"

      return I18n.t(
        "#{record_class.model_name.i18n_key.to_s.pluralize}.#{scope}.#{key}",
        default: key.humanize
      )
    end

    if attribute.end_with?("_type")
      key = value.to_s.demodulize.underscore

      return I18n.t(
        "#{record_class.model_name.i18n_key.to_s.pluralize}.sources.#{key}",
        default: value.to_s
      )
    end

    if attribute.end_with?("_id")
      association = attribute.delete_suffix("_id")
      reflection = record_class.reflect_on_association(association)

      if reflection && !reflection.polymorphic?
        record = reflection.klass.find_by(id: value)

        return record.try(:name) ||
              record.try(:fullname) ||
              record.try(:title) ||
              value
      end
    end

    value
  end

end