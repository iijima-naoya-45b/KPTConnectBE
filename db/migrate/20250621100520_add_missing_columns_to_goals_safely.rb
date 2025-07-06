class AddMissingColumnsToGoalsSafely < ActiveRecord::Migration[8.0]
  def change
    if table_exists?(:goals)
      unless column_exists?(:goals, :status)
        add_column :goals, :status, :string, default: 'not_started', null: false
      end

      unless column_exists?(:goals, :progress_check)
        add_column :goals, :progress_check, :text
      end

      unless column_exists?(:goals, :created_by_ai)
        add_column :goals, :created_by_ai, :boolean, default: false, null: false
      end
    end
  end
end
