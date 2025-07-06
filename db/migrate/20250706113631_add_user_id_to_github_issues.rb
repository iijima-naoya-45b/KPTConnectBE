class AddUserIdToGithubIssues < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:github_issues, :user_id)
      add_column :github_issues, :user_id, :integer, null: false
    end
  end
end
