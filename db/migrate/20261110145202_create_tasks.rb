class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.bigint :parent_id
      t.bigint :author_id, null: false
      t.string :task_title, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false
      t.boolean :requires_review, default: false, null: false
      t.datetime :start_at
      t.datetime :deadline
      t.datetime :completed_at
      t.datetime :reviewed_at
      t.decimal :work_duration, precision: 15, scale: 2, default: "0.0", null: false

      t.timestamps
    end

    add_index :tasks, :author_id
    add_index :tasks, :parent_id
  end
end