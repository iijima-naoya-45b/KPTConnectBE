class AddDateRangeToKptItems < ActiveRecord::Migration[8.0]
  def change
    add_column :kpt_items, :start_date, :date
    add_column :kpt_items, :end_date, :date
  end
end
