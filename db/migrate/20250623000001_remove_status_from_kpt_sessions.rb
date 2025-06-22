class RemoveStatusFromKptSessions < ActiveRecord::Migration[7.1]
  def change
    remove_column :kpt_sessions, :status, :string
  end
end
