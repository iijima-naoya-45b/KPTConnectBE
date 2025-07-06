class AddUserIdToGithubIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :github_issues, :user_id, :integer, null: false
  end
end
