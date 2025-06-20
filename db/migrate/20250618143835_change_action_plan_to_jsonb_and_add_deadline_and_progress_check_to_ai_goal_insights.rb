class ChangeActionPlanToJsonbAndAddDeadlineAndProgressCheckToAiGoalInsights < ActiveRecord::Migration[8.0]
  def up
    # action_plan: text -> jsonb
    change_column :ai_goal_insights, :action_plan, 'jsonb USING CASE WHEN action_plan IS NULL OR action_plan = '' THEN ''[]''::jsonb ELSE to_jsonb(array[action_plan]) END', default: '[]', null: false
    # deadline: date
    add_column :ai_goal_insights, :deadline, :date
    # progress_check: text
    add_column :ai_goal_insights, :progress_check, :text
  end

  def down
    # action_plan: jsonb -> text
    change_column :ai_goal_insights, :action_plan, :text
    remove_column :ai_goal_insights, :deadline
    remove_column :ai_goal_insights, :progress_check
  end
end
