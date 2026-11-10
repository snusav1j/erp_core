class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :system_role
      t.boolean :banned, default: false, null: false
      t.string :last_name
      t.string :first_name
      t.string :middle_name
      t.string :phone
      t.datetime :last_seen_at
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip
      t.bigint :role_id

      t.timestamps
    end

    add_index :users, :banned
    add_index :users, :email, unique: true
    add_index :users, :phone
    add_index :users, :reset_password_token, unique: true
    add_index :users, :role_id
    add_index :users, :system_role
  end
end