class AddFeedbackCategoryToFeedbacks < ActiveRecord::Migration[8.0]
  def change
    add_column :feedbacks, :feedbackCategory, :integer
  end
end
