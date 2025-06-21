class AddActionPlanToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :action_plan, :json, default: []
  end
end
