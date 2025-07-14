class AddTypeToFeedbackTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :feedback_types, :type, :string
  end
end
