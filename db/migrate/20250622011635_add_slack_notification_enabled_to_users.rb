class AddSlackNotificationEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :slack_notification_enabled, :boolean, default: false, null: false
  end
end
