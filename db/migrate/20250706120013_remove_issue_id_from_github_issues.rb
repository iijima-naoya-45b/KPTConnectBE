class RemoveIssueIdFromGithubIssues < ActiveRecord::Migration[8.0]
  def change
    remove_column :github_issues, :issue_id, :integer
  end
end
