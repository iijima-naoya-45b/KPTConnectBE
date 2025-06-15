class CreateKptReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :kpt_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :description
      t.text :keep
      t.text :problem
      t.text :try

      t.timestamps
    end
  end
end
