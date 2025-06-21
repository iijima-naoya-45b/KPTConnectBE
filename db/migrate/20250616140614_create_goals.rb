class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :progress, default: 0, null: false
      t.text :description
      t.date :deadline
      t.json :action_plan, default: []
      t.string :status, default: 'not_started', null: false
      t.text :progress_check
      t.boolean :created_by_ai, default: false, null: false

      t.timestamps
    end
  end
end
