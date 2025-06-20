class AddProgressToAiGoalInsights < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_goal_insights, :progress, :integer, default: 0, null: false
  end
end
