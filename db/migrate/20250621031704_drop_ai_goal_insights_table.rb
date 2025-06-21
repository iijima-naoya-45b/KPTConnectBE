class DropAiGoalInsightsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :ai_goal_insights do |t|
      t.bigint "user_id"
      t.string "title"
      t.text "description"
      t.jsonb "action_plan", default: "[]", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.date "deadline"
      t.text "progress_check"
      t.date "milestone"
      t.string "status", default: "not_started", null: false
      t.integer "progress", default: 0, null: false
      t.index ["status"], name: "index_ai_goal_insights_on_status"
      t.check_constraint "status::text = ANY (ARRAY['not_started'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'paused'::character varying]::text[])", name: "check_ai_goal_insights_status"
    end
  end
end
