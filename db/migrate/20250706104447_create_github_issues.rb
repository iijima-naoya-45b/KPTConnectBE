class CreateGithubIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :github_issues do |t|
      t.integer :issue_id, null: false
      t.string :title
      t.text :body
      t.string :state

      t.timestamps
    end
  end
end