class ChangeFeedbackTypeColumn < ActiveRecord::Migration[8.0]
  def change
    add_column :feedbacks, :type, :string
  end
end
