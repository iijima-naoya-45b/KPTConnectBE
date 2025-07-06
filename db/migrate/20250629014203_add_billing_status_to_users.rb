class AddBillingStatusToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :billing_status, :string, default: 'false'
  end
end
