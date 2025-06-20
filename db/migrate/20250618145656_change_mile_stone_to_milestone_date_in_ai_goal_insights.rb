class ChangeMileStoneToMilestoneDateInAiGoalInsights < ActiveRecord::Migration[8.0]
  def change
    remove_column :ai_goal_insights, :mile_stone, :text
    add_column :ai_goal_insights, :milestone, :date
  end
end
