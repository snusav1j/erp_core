module BreadcrumbsHelper
  BREADCRUMB_CONFIG = {
    "clients" => {
      field: [:name]
    },
    "client_types" => {
      field: [:name],
      parents: ["clients"]
    },
    "client_statuses" => {
      field: [:name],
      parents: ["clients"]
    },
    "interactions" => {
      field: [:client, :name],
      parents: ["clients"]
    },
    "interaction_types" => {
      field: [:name],
      parents: ["clients", "interactions"]
    },
    "suppliers" => {
      field: [:name]
    },
    "products" => {
      field: [:name]
    },
    "product_categories" => {
      field: [:name],
      parents: ["products"]
    },
    "units" => {
      field: [:name],
      parents: ["products"]
    },
    "expense_categories" => {
      field: [:name],
      parents: ["expenses"]
    },
    "purchases" => {
      field: [:supplier, :name],
      parents: ["suppliers"],
      order: [:parents,:resource, :record, :title]
    },
    "productions" => {
      field: [:product, :name],
      parents: ["products"],
      append_title: false
    },
    "product_components" => {
      field: [:product, :name],
      parents: ["products"]
    },
    "warehouses" => {
      field: [:name]
    },
    "transfers" => {
      parents: ["warehouses", "warehouse_stocks"]
    },
    "inventories" => {
      parents: ["warehouses", "warehouse_stocks"]
    },
    "stock_movements" => {
      parents: ["warehouses", "warehouse_stocks"]
    },
    "warehouse_stocks" => {
      parents: ["warehouses"]
    },
    "orders" => {
      field: [:client, :name],
      parents: ["clients"]
    },
    "returns" => {
      field: [:order, :client, :name],
      parents: ["clients", "orders"]
    },
    "bank_accounts" => {
      field: [:name]
    },
    "currencies" => {
      field: [:name]
    },
    "rates" => {
      field: [:currency, :name],
      parents: ["currencies"]
    },
    "financial_operations" => {
      field: [:source, :name],
      parents: ["bank_accounts"]
    },
    "financial_operation_payments" => {
      field: [:source, :name],
      parents: ["bank_accounts", "financial_operations"]
    },
    "users" => {
      field: [:first_name],
      parents: ["companies"],
      append_title: false
    },
    "companies" => {
      field: [:name]
    },
    "roles" => {
      field: [:name]
    }
  }.freeze

  def breadcrumbs
    @breadcrumbs ||= []
  end

  def add_breadcrumb(title, path = nil)
    breadcrumbs << { title: title, path: path }
  end

  def render_breadcrumbs
    render "shared/breadcrumbs", breadcrumbs: breadcrumbs
  end

  def setup_crud_breadcrumbs(record = nil)
    @breadcrumbs = []

    model_class = record&.class || controller_name.classify.constantize
    resource_path = polymorphic_path(model_class)

    add_breadcrumb(tgm(:root), clients_path)

    record ||= breadcrumb_record(model_class)

    breadcrumb_items(model_class, resource_path, record).each do |item|
      add_breadcrumb(item[:title], item[:path])
    end
  end

  private

  def breadcrumb_config(model_class = nil)
    controller = model_class ? model_class.model_name.route_key : controller_name
    BREADCRUMB_CONFIG[controller] || {}
  end

  def breadcrumb_parents(model_class = nil)
    breadcrumb_config(model_class)[:parents] || []
  end

  def breadcrumb_order(model_class = nil)
    breadcrumb_config(model_class)[:order] || [:parents, :resource, :record, :title]
  end

  def breadcrumb_append_title?(model_class = nil)
    config = breadcrumb_config(model_class)
    config.fetch(:append_title, breadcrumb_parents(model_class).any?)
  end

  def breadcrumb_record_field(model_class = nil)
    breadcrumb_config(model_class)[:field] || [:id]
  end

  def breadcrumb_record(model_class)
    record = instance_variable_get("@#{model_class.model_name.element}")

    return record if record&.persisted?
    return unless params[:id].present?

    model_class.find_by(id: params[:id])
  end

  def breadcrumb_items(model_class, resource_path, record)
    items = []

    breadcrumb_order(model_class).each do |item|
      case item
      when :parents
        items.concat(breadcrumb_parent_items(model_class))
      when :resource
        items << {
          title: model_class.model_name.human(count: 2),
          path: resource_path
        }
      when :record
        if record
          items << {
            title: breadcrumb_record_name(record, model_class),
            path: breadcrumb_record_path(record, model_class)
          }
        end
      when :title
        if record && breadcrumb_append_title?(model_class)
          items << {
            title: "#{tm(model_class, :title_single)} ##{record.id}",
            path: polymorphic_path(record)
          }
        end
      when :new
        items << {
          title: tgm(:new),
          path: nil
        }
      when :edit
        if action_name == "edit"
          items << {
            title: tgm(:edit),
            path: nil
          }
        end
      end
    end

    if action_name == "index"
      resource_item = items.find { |item| item[:title] == model_class.model_name.human(count: 2) }
      resource_item[:path] = nil if resource_item
    end

    items
  end

  def breadcrumb_parent_items(model_class = nil)
    breadcrumb_parents(model_class).map do |parent_controller|
      parent_model = parent_controller.classify.constantize

      {
        title: parent_model.model_name.human(count: 2),
        path: polymorphic_path(parent_model)
      }
    end
  end

  def breadcrumb_record_name(record, model_class = nil)
    return "##{record.id}" unless record

    fields = breadcrumb_record_field(model_class)
    value = record

    fields.each do |field|
      return "##{record.id}" unless value.respond_to?(field)

      value = value.public_send(field)
      break if value.nil?
    end

    value.present? ? value : "##{record.id}"
  end

  def breadcrumb_record_path(record, model_class = nil)
    return unless record

    fields = breadcrumb_record_field(model_class)
    value = record

    fields.each do |field|
      return polymorphic_path(record) unless value.respond_to?(field)

      value = value.public_send(field)

      if value.respond_to?(:model_name)
        return polymorphic_path(value)
      end

      break if value.nil?
    end

    polymorphic_path(record)
  end
end