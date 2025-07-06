class AddUserReferenceToGithubIssues < ActiveRecord::Migration[8.0]
  def change
    add_reference :github_issues, :user, null: false
  end
end
