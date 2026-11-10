class CreateTableFilterValues < ActiveRecord::Migration[8.0]
  def change
    create_table :table_filter_values do |t|
      t.string :entity
      t.string :column_key
      t.text :value
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end