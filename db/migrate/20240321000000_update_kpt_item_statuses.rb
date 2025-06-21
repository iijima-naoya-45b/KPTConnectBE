# frozen_string_literal: true

class UpdateKptItemStatuses < ActiveRecord::Migration[7.0]
  def up
    # テーブルが存在するかチェック
    return unless table_exists?(:kpt_items)
    
    # 既存のstatus値を新しい値に変換
    execute <<-SQL
      UPDATE kpt_items
      SET status = CASE
        WHEN status IN ('todo', 'new', 'pending') THEN 'open'
        WHEN status IN ('doing', 'in_progress', 'started') THEN 'in_progress'
        WHEN status IN ('done', 'finished', 'resolved') THEN 'completed'
        WHEN status IN ('cancelled', 'closed', 'rejected') THEN 'cancelled'
        ELSE 'open'
      END
    SQL

    # statusカラムにCHECK制約を追加
    execute <<-SQL
      ALTER TABLE kpt_items
      ADD CONSTRAINT check_status_values
      CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled'))
    SQL
  end

  def down
    # テーブルが存在するかチェック
    return unless table_exists?(:kpt_items)
    
    # CHECK制約を削除
    execute <<-SQL
      ALTER TABLE kpt_items
      DROP CONSTRAINT IF EXISTS check_status_values
    SQL
  end
end 