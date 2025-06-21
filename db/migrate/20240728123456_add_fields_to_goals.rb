class AddFieldsToGoals < ActiveRecord::Migration[7.0]
  def change
    # AiGoalInsightからカラムを移行
    add_column :goals, :status, :string, default: 'not_started', null: false
    add_column :goals, :progress_check, :text

    # AIによって作成されたかを識別するフラグ
    add_column :goals, :created_by_ai, :boolean, default: false, null: false

    # 既存のカラムもAiGoalInsightに合わせて調整（デフォルト値やnull制約など）
    change_column_null :goals, :title, false
    change_column_null :goals, :progress, false, 0
    change_column_default :goals, :progress, from: nil, to: 0
    change_column_default :goals, :action_plan, from: nil, to: []
  end
end 