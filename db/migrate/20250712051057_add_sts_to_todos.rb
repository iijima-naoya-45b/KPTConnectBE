class AddStsToTodos < ActiveRecord::Migration[8.0]
  def change
    add_column :todos, :status, :string, default: 'open'
  end
end
