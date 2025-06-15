# frozen_string_literal: true

# kpt_items.statusカラムのCHECK制約を削除するマイグレーション
class RemoveStatusCheckConstraintFromKptItems < ActiveRecord::Migration[7.0]
  def up
    # 制約名が異なる場合も考慮して両方削除
    execute <<-SQL
      ALTER TABLE kpt_items DROP CONSTRAINT IF EXISTS check_kpt_items_status;
      ALTER TABLE kpt_items DROP CONSTRAINT IF EXISTS check_status_values;
    SQL
  end

  def down
    # 必要なら元の制約を再追加
    execute <<-SQL
      ALTER TABLE kpt_items ADD CONSTRAINT check_kpt_items_status CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled'));
      ALTER TABLE kpt_items ADD CONSTRAINT check_status_values CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled'));
    SQL
  end
end 