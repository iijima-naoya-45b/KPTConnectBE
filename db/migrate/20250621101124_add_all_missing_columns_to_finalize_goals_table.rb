class AddAllMissingColumnsToFinalizeGoalsTable < ActiveRecord::Migration[8.0]
  def change
    if table_exists?(:goals)
      # action_plan カラムが存在しない場合のみ追加
      unless column_exists?(:goals, :action_plan)
        add_column :goals, :action_plan, :json, default: []
      end

      # status カラムが存在しない場合のみ追加
      unless column_exists?(:goals, :status)
        add_column :goals, :status, :string, default: 'not_started', null: false
      end

      # progress_check カラムが存在しない場合のみ追加
      unless column_exists?(:goals, :progress_check)
        add_column :goals, :progress_check, :text
      end

      # created_by_ai カラムが存在しない場合のみ追加
      unless column_exists?(:goals, :created_by_ai)
        add_column :goals, :created_by_ai, :boolean, default: false, null: false
      end
    end
  end
end
