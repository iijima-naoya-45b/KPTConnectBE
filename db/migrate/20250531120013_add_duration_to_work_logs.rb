# frozen_string_literal: true

# 作業ログテーブルに継続時間計算カラム追加マイグレーション
# PostgreSQLの生成カラム機能を使用して自動計算
class AddDurationToWorkLogs < ActiveRecord::Migration[7.0]
  def change
    # PostgreSQLの生成カラム機能を使用して継続時間を自動計算
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE work_logs 
          ADD COLUMN duration_minutes INTEGER 
          GENERATED ALWAYS AS (
            CASE 
              WHEN ended_at IS NOT NULL THEN 
                EXTRACT(EPOCH FROM (ended_at - started_at))/60
              ELSE NULL 
            END
          ) STORED;
        SQL

        # 継続時間にインデックスを追加
        add_index :work_logs, :duration_minutes
      end

      dir.down do
        remove_index :work_logs, :duration_minutes
        remove_column :work_logs, :duration_minutes
      end
    end
  end
end