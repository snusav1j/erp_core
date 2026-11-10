class UserSetting < ApplicationRecord
  belongs_to :user

  def set_table_per_page(entity, per_page)
    per_page = per_page.to_i

    return unless ApplicationRecord::PER_PAGE_COLLECTION.include?(per_page)

    table_per_page = self.table_per_page || {}
    table_per_page[entity.to_s] = per_page

    update!(table_per_page: table_per_page)
  end

  def get_table_per_page(entity)
    value = table_per_page&.[](entity.to_s)

    value = value.to_i if value.present?

    ApplicationRecord::PER_PAGE_COLLECTION.include?(value) ? value : ApplicationRecord::PER_PAGE
  end
end