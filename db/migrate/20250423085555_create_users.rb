class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :username
      t.string :provider, null: false
      t.string :uid, null: false

      t.timestamps
    end

    add_index :users, [ :provider, :uid ], unique: true
    add_index :users, :email, unique: true
  end
end
