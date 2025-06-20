class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :progress, default: 0
      t.text :description
      t.date :deadline

      t.timestamps
    end
  end
end
