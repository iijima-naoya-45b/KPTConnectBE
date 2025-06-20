class CreateAiGoalInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_goal_insights do |t|
      t.bigint :user_id
      t.string :title
      t.text :description
      t.text :mile_stone
      t.text :action_plan

      t.timestamps
    end
  end
end
