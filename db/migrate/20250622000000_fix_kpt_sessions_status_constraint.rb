# frozen_string_literal: true

# KPTセッションのステータス制約を修正するマイグレーション
class FixKptSessionsStatusConstraint < ActiveRecord::Migration[8.0]
  def up
    # 既存の制約を削除
    execute <<-SQL
      ALTER TABLE kpt_sessions DROP CONSTRAINT IF EXISTS check_kpt_sessions_status;
    SQL

    # 既存データを新しい値に変換
    execute <<-SQL
      UPDATE kpt_sessions 
      SET status = CASE
        WHEN status = 'draft' THEN 'not_started'
        WHEN status = 'archived' THEN 'pending'
        ELSE status
      END
      WHERE status IN ('draft', 'archived');
    SQL

    # 新しい制約を追加
    execute <<-SQL
      ALTER TABLE kpt_sessions
      ADD CONSTRAINT check_kpt_sessions_status
      CHECK (status IN ('not_started', 'in_progress', 'completed', 'pending'));
    SQL
  end

  def down
    # 制約を削除
    execute <<-SQL
      ALTER TABLE kpt_sessions DROP CONSTRAINT IF EXISTS check_kpt_sessions_status;
    SQL

    # データを元の値に戻す
    execute <<-SQL
      UPDATE kpt_sessions 
      SET status = CASE
        WHEN status = 'not_started' THEN 'draft'
        WHEN status = 'pending' THEN 'archived'
        ELSE status
      END
      WHERE status IN ('not_started', 'pending');
    SQL

    # 元の制約を追加
    execute <<-SQL
      ALTER TABLE kpt_sessions
      ADD CONSTRAINT check_kpt_sessions_status
      CHECK (status IN ('draft', 'in_progress', 'completed', 'archived'));
    SQL
  end
end 