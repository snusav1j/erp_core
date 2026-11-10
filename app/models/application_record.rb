class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  primary_abstract_class

  class_attribute :table_includes, default: []

  before_validation :strip_string_attributes

  PER_PAGE = 15
  PER_PAGE_COLLECTION = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

  def self.table_per_page(user)
    return PER_PAGE unless user

    user.user_setting&.get_table_per_page(self.name) || PER_PAGE
  end

  def self.filter_collections
    {}
  end

  def self.filter(filters, user, page: nil)
    filters = filters.presence || {}

    saved_values = TableFilterValue.where(
      entity: self.name,
      user: user
    ).pluck(:column_key, :value).to_h

    saved_page = saved_values.delete("page")

    page ||= saved_page.presence || 1

    if filters.empty?
      filters = saved_values
    end

    collections = self.filter_collections

    result = self.all

    result = result.includes(*self.table_includes) if self.table_includes.present?

    filters.each do |key, value|
      value = value.strip if value.is_a?(String)

      next unless self.column_names.include?(key.to_s)
      next if value.blank?

      field_type = collections.key?(key.to_sym) ? :collection : self.columns_hash[key.to_s].type

      next if field_type == :boolean && value == "0"

      case field_type
      when :collection
        result = result.where(key => value)

      when :string, :text
        result = result.merge(
          smart_search(
            column: key,
            query: value
          )
        )

      when :integer, :bigint, :float, :decimal, :number
        result = result.where(key => value)

      when :date
        date = Date.parse(value)

        result = result.where(
          key => date.beginning_of_day..date.end_of_day
        )

      when :datetime
        date = Date.parse(value)

        result = result.where(
          key => date.beginning_of_day..date.end_of_day
        )

      when :boolean
        result = result.where(key => value == "1")
      end
    end

    result = result.order(created_at: :desc) if column_names.include?("created_at")

    per_page = self.table_per_page(user)

    total_count = result.count
    total_pages = (total_count.to_f / per_page).ceil

    page = 1 if total_pages.zero? || page.to_i > total_pages

    if total_count > per_page
      result.page(page).per(per_page)
    else
      result
    end
  end

  def self.smart_search(column:, query:)
    query = self.normalize_search(query)

    return self.none if query.blank?

    columns = Array(column).map(&:to_s)
    allowed_columns = self.column_names

    return self.none unless columns.present?
    return self.none unless columns.all? { |name| allowed_columns.include?(name) }

    quoted_table = self.connection.quote_table_name(self.table_name)
    quoted_columns = columns.map { |name| self.connection.quote_column_name(name) }

    if query.length < 4
      conditions = quoted_columns.map do |quoted_column|
        "#{quoted_table}.#{quoted_column} ILIKE :query"
      end

      return self.where(
        conditions.join(" OR "),
        query: "%#{query}%"
      )
    end

    words = query.split
    compact_query = words.join

    word_conditions = []
    params = {
      compact_query: "%#{compact_query}%"
    }

    words.each_with_index do |word, index|
      key = "word_#{index}"
      clear_key = "clear_#{index}"

      column_conditions = quoted_columns.map do |quoted_column|
        normalized_column = self.normalized_search_column(quoted_table, quoted_column)

        <<~SQL
          EXISTS (
            SELECT 1
            FROM regexp_split_to_table(
              #{normalized_column},
              '\\s+'
            ) AS name_word
            WHERE
              name_word LIKE :#{key}
              OR (
                levenshtein(name_word, :#{clear_key}) <= CASE
                  WHEN LENGTH(:#{clear_key}) >= 8 THEN 2
                  WHEN LENGTH(:#{clear_key}) >= 5 THEN 1
                  ELSE 0
                END
              )
          )
        SQL
      end

      word_conditions << "(#{column_conditions.join(" OR ")})"

      params[key.to_sym] = "%#{word}%"
      params[clear_key.to_sym] = word.delete(" ")
    end

    compact_conditions = quoted_columns.map do |quoted_column|
      normalized_column = self.normalized_search_column(quoted_table, quoted_column)
      compact_column = "REPLACE(#{normalized_column}, ' ', '')"

      "#{compact_column} LIKE :compact_query"
    end

    conditions = <<~SQL
      (
        #{compact_conditions.join(" OR ")}
        OR
        (
          #{word_conditions.join(" AND ")}
        )
      )
    SQL

    self.where(conditions, **params)
  end

  def self.normalized_search_column(quoted_table, quoted_column)
    "LOWER(TRANSLATE(#{quoted_table}.#{quoted_column}, '-_()[]', '      '))"
  end

  def self.normalize_search(value)
    value.to_s
      .downcase
      .gsub(/[«»"'`]/, "")
      .gsub(/[(){}\[\]]/, "")
      .gsub(/[.,;:\/\\_\-]+/, " ")
      .gsub(/\s+/, " ")
      .strip
  end

  private

  def strip_string_attributes
    self.attributes.each do |attribute, value|
      self[attribute] = value.strip if value.is_a?(String)
    end
  end
end