class Statistics::Products
  SOLD_STATUSES = [:completed, :returning, :returned].freeze
  PROFIT_STATUSES = [:completed, :returning, :returned].freeze
  ORDER_STATUSES = [:confirmed, :completed, :returning, :returned, :in_delivery].freeze
  RETURN_STATUSES = [:accepted, :completed].freeze

  def initialize(products)
    @single_product = products.is_a?(Product)

    @product_ids =
      if @single_product
        [products.id]
      elsif products.is_a?(Class)
        products.pluck(:id)
      else
        products.pluck(:id)
      end

    @statistics = {}
    @current_start = Time.current.beginning_of_month
    @current_end = @current_start.end_of_month
    @previous_start = @current_start.prev_month.beginning_of_month
    @previous_end = @previous_start.end_of_month
  end

  def statistics
    return @single_product ? nil : {} if @product_ids.empty?

    self.load_statistics

    @single_product ? @statistics[@product_ids.first] : @statistics
  end

  private

  def load_statistics
    self.initialize_statistics
    self.load_warehouse_quantities
    self.load_stock_reservations
    self.load_in_transit
    self.load_sold_counts
    self.load_order_counts
    self.load_return_counts
    self.load_profits
    self.load_records
  end

  def initialize_statistics
    @product_ids.each do |product_id|
      @statistics[product_id] = {
        details: {
          sold_count: self.empty_comparison,
          order_count: self.empty_comparison,
          in_transit: 0,
          profit: self.empty_comparison,
          return_items: self.empty_comparison,
          warehouse_quantity: 0,
          reserved_quantity: 0
        },
        records: {
          warehouse_stocks: [],
          stock_reservations: [],
          stock_batches: [],
          stock_items: [],
          order_items: [],
          orders: [],
          return_items: [],
          returns: []
        }
      }
    end
  end

  def load_warehouse_quantities
    WarehouseStock
      .where(product_id: @product_ids)
      .group(:product_id)
      .sum(:quantity)
      .each do |product_id, quantity|
        @statistics[product_id][:details][:warehouse_quantity] = quantity
      end
  end

  def load_stock_reservations
    batch_products = StockBatch
      .where(product_id: @product_ids)
      .pluck(:id, :product_id)
      .to_h

    item_products = StockItem
      .where(product_id: @product_ids)
      .pluck(:id, :product_id)
      .to_h

    return if batch_products.empty? && item_products.empty?

    if batch_products.any?
      StockReservation
        .where(stock_batch_id: batch_products.keys)
        .group(:stock_batch_id)
        .sum(:quantity)
        .each do |stock_batch_id, quantity|
          product_id = batch_products[stock_batch_id]
          @statistics[product_id][:details][:reserved_quantity] += quantity
        end
    end

    if item_products.any?
      StockReservation
        .where(stock_item_id: item_products.keys)
        .group(:stock_item_id)
        .sum(:quantity)
        .each do |stock_item_id, quantity|
          product_id = item_products[stock_item_id]
          @statistics[product_id][:details][:reserved_quantity] += quantity
        end
    end
  end

  def load_in_transit
    batch_products = StockBatch
      .where(product_id: @product_ids)
      .pluck(:id, :product_id)
      .to_h

    item_products = StockItem
      .where(product_id: @product_ids)
      .pluck(:id, :product_id)
      .to_h

    if batch_products.any?
      StockReservation
        .in_transit
        .where(stock_batch_id: batch_products.keys)
        .group(:stock_batch_id)
        .sum(:quantity)
        .each do |stock_batch_id, quantity|
          product_id = batch_products[stock_batch_id]
          @statistics[product_id][:details][:in_transit] += quantity
        end
    end

    if item_products.any?
      StockReservation
        .in_transit
        .where(stock_item_id: item_products.keys)
        .group(:stock_item_id)
        .sum(:quantity)
        .each do |stock_item_id, quantity|
          product_id = item_products[stock_item_id]
          @statistics[product_id][:details][:in_transit] += quantity
        end
    end
  end

  def load_sold_counts
    return_quantities = ReturnItem
      .joins(:return)
      .where(order_item_id: OrderItem.where(product_id: @product_ids).select(:id))
      .group(:order_item_id)
      .sum(:accepted_quantity)

    order_items = OrderItem
      .joins(:order)
      .where(product_id: @product_ids)
      .where(orders: { status: SOLD_STATUSES })
      .where(orders: { created_at: @previous_start..@current_end })
      .pluck(:id, :product_id, :quantity, 'orders.created_at')

    current = Hash.new(0)
    previous = Hash.new(0)

    order_items.each do |order_item_id, product_id, quantity, created_at|
      returned_quantity = return_quantities[order_item_id].to_d
      sold_quantity = [quantity.to_d - returned_quantity, 0].max

      if created_at >= @current_start
        current[product_id] += sold_quantity
      else
        previous[product_id] += sold_quantity
      end
    end

    @product_ids.each do |product_id|
      @statistics[product_id][:details][:sold_count] = self.comparison(
        current[product_id],
        previous[product_id]
      )
    end
  end

  def load_order_counts
    current_start = OrderItem.connection.quote(@current_start)
    current_end = OrderItem.connection.quote(@current_end)
    previous_start = OrderItem.connection.quote(@previous_start)
    previous_end = OrderItem.connection.quote(@previous_end)

    current_expression = <<~SQL.squish
      COUNT(DISTINCT CASE
        WHEN orders.created_at BETWEEN #{current_start} AND #{current_end}
        THEN orders.id
      END)
    SQL

    previous_expression = <<~SQL.squish
      COUNT(DISTINCT CASE
        WHEN orders.created_at BETWEEN #{previous_start} AND #{previous_end}
        THEN orders.id
      END)
    SQL

    rows = OrderItem
      .joins(:order)
      .where(product_id: @product_ids)
      .where(orders: { status: ORDER_STATUSES })
      .where(orders: { created_at: @previous_start..@current_end })
      .group(:product_id)
      .pluck(
        :product_id,
        Arel.sql(current_expression),
        Arel.sql(previous_expression)
      )

    rows.each do |product_id, current, previous|
      @statistics[product_id][:details][:order_count] = self.comparison(
        current.to_i,
        previous.to_i
      )
    end
  end

  def load_return_counts
    current_start = ReturnItem.connection.quote(@current_start)
    current_end = ReturnItem.connection.quote(@current_end)
    previous_start = ReturnItem.connection.quote(@previous_start)
    previous_end = ReturnItem.connection.quote(@previous_end)

    current_expression = <<~SQL.squish
      SUM(CASE
        WHEN return_items.created_at BETWEEN #{current_start} AND #{current_end}
        THEN return_items.accepted_quantity
        ELSE 0
      END)
    SQL

    previous_expression = <<~SQL.squish
      SUM(CASE
        WHEN return_items.created_at BETWEEN #{previous_start} AND #{previous_end}
        THEN return_items.accepted_quantity
        ELSE 0
      END)
    SQL

    rows = ReturnItem
      .joins(:return)
      .where(product_id: @product_ids)
      .where(returns: { status: RETURN_STATUSES })
      .where(created_at: @previous_start..@current_end)
      .group(:product_id)
      .pluck(
        :product_id,
        Arel.sql(current_expression),
        Arel.sql(previous_expression)
      )

    rows.each do |product_id, current, previous|
      @statistics[product_id][:details][:return_items] = self.comparison(
        current.to_d,
        previous.to_d
      )
    end
  end

  def load_profits
    current = self.profit_values(@current_start, @current_end)
    previous = self.profit_values(@previous_start, @previous_end)

    @product_ids.each do |product_id|
      @statistics[product_id][:details][:profit] = self.comparison(
        current[product_id] || 0.to_d,
        previous[product_id] || 0.to_d
      )
    end
  end

  def profit_values(period_start, period_end)
    target_items = OrderItem
      .joins(:order)
      .where(product_id: @product_ids)
      .where(orders: { status: PROFIT_STATUSES })
      .where(orders: { created_at: period_start..period_end })
      .pluck(
        :id,
        :product_id,
        :quantity,
        :sale_price,
        :purchase_price,
        :stock_batch_id,
        :stock_item_id
      )

    return {} if target_items.empty?

    return_quantities = ReturnItem
      .where(order_item_id: target_items.map(&:first))
      .group(:order_item_id)
      .sum(:accepted_quantity)

    batch_ids = target_items.map { |item| item[5] }.compact.uniq
    item_ids = target_items.map { |item| item[6] }.compact.uniq

    batch_costs =
      if batch_ids.any?
        StockBatch.where(id: batch_ids).pluck(:id, :cost_price_per_unit).to_h
      else
        {}
      end

    item_costs =
      if item_ids.any?
        StockItem.where(id: item_ids).pluck(:id, :cost_price_per_unit).to_h
      else
        {}
      end

    result = Hash.new(0.to_d)

    target_items.each do |item|
      item_id = item[0]
      product_id = item[1]
      quantity = item[2].to_d
      sale_price = item[3].to_d
      purchase_price = item[4]
      stock_batch_id = item[5]
      stock_item_id = item[6]

      returned_quantity = return_quantities[item_id].to_d
      remaining_quantity = [quantity - returned_quantity, 0].max

      item_income = remaining_quantity * sale_price

      cost =
        batch_costs[stock_batch_id] ||
        item_costs[stock_item_id] ||
        purchase_price.to_d

      item_expense = remaining_quantity * cost.to_d

      result[product_id] += item_income - item_expense
    end

    result
  end

  def load_records
    warehouse_stocks = WarehouseStock
      .where(product_id: @product_ids)
      .includes(:warehouse)

    warehouse_stocks.each do |warehouse_stock|
      @statistics[warehouse_stock.product_id][:records][:warehouse_stocks] << warehouse_stock
    end

    stock_batches = StockBatch
      .where(product_id: @product_ids)

    stock_items = StockItem
      .where(product_id: @product_ids)

    stock_batch_ids = stock_batches.pluck(:id)
    stock_item_ids = stock_items.pluck(:id)

    stock_batches.each do |stock_batch|
      @statistics[stock_batch.product_id][:records][:stock_batches] << stock_batch
    end

    stock_items.each do |stock_item|
      @statistics[stock_item.product_id][:records][:stock_items] << stock_item
    end

    reservations = StockReservation
      .where(stock_batch_id: stock_batch_ids)
      .or(StockReservation.where(stock_item_id: stock_item_ids))

    reservations.each do |reservation|
      product_id =
        if reservation.stock_batch_id.present?
          stock_batches.find { |stock_batch| stock_batch.id == reservation.stock_batch_id }&.product_id
        elsif reservation.stock_item_id.present?
          stock_items.find { |stock_item| stock_item.id == reservation.stock_item_id }&.product_id
        end

      next unless product_id

      @statistics[product_id][:records][:stock_reservations] << reservation
    end

    order_items = OrderItem
      .where(product_id: @product_ids)
      .includes(:order, :stock_batch, :stock_item)

    order_items.each do |order_item|
      @statistics[order_item.product_id][:records][:order_items] << order_item
      @statistics[order_item.product_id][:records][:orders] << order_item.order unless @statistics[order_item.product_id][:records][:orders].include?(order_item.order)
    end

    return_items = ReturnItem
      .where(order_item_id: order_items.map(&:id))
      .includes(:return, :order_item)

    return_items.each do |return_item|
      product_id = return_item.order_item.product_id

      @statistics[product_id][:records][:return_items] << return_item
      @statistics[product_id][:records][:returns] << return_item.return unless @statistics[product_id][:records][:returns].include?(return_item.return)
    end
  end

  def empty_comparison
    {
      current: 0,
      previous: 0,
      difference: 0
    }
  end

  def comparison(current, previous)
    {
      current: current,
      previous: previous,
      difference: current - previous
    }
  end
end