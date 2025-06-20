class AddStatusToAiGoalInsights < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_goal_insights, :status, :string, default: 'not_started', null: false
    add_index :ai_goal_insights, :status
    
    # 制約を追加（着手前、着手中、完了、保留）
    add_check_constraint :ai_goal_insights, 
                        "status IN ('not_started', 'in_progress', 'completed', 'paused')", 
                        name: 'check_ai_goal_insights_status'
  end
end 