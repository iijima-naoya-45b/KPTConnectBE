class AddUserIdToGithubIssues < ActiveRecord::Migration[8.0]
  def change
    add_column :github_issues, :user_id, :integer, null: false
    add_foreign_key :github_issues, :users
  end
end
