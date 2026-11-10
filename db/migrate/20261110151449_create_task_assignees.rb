class CreateTaskAssignees < ActiveRecord::Migration[8.0]
  def change
    create_table :task_assignees do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :task_assignees, [:task_id, :user_id], unique: true
  end
end