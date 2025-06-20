class AddProgressCheckToAiGoalInsights < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_goal_insights, :progress_check, :text
  end
end
