class VersionsController < ApplicationController
  skip_before_action :load_table_data

  def modal
    model_class = EntityRegistry.get(params[:model])
    raise ActiveRecord::RecordNotFound unless model_class

    @record = model_class.find(params[:id])
    @versions = versions_for(@record)

    respond_to :js
  end

  def changeset
    @version = Version.find_by(id: params[:id])

    respond_to :js
  end

  private

  def versions_for(record)
    versions = Version.where(item_type: record.class.name, item_id: record.id)

    if record.class.custom_fields_enabled
      custom_value_ids = record.custom_field_values.pluck(:id)

      versions = versions.or(
        Version.where(item_type: "CustomFieldValue", item_id: custom_value_ids)
      )
    end

    if record.is_a?(Purchase)
      purchase_item_ids = record.purchase_items.pluck(:id)

      versions = versions.or(
        Version.where(item_type: "PurchaseItem", item_id: purchase_item_ids)
      )
    end

    if record.is_a?(Order)
      order_item_ids = record.order_items.pluck(:id)

      versions = versions.or(
        Version.where(item_type: "OrderItem", item_id: order_item_ids)
      )
    end

    if record.is_a?(Purchase) || record.is_a?(Order)
      stock_movement_ids = record.stock_movements.pluck(:id)

      versions = versions.or(
        Version.where(item_type: "StockMovement", item_id: stock_movement_ids)
      )
    end

    versions.order(created_at: :desc)
  end
end