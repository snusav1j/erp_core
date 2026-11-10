class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.bigint :user_id
      t.boolean :hide_sidebar, default: false
      t.jsonb :table_per_page, default: {}

      t.timestamps
    end

    add_index :user_settings, :user_id
  end
end