# frozen_string_literal: true

# 作業ログテーブル作成マイグレーション
# 振り返りの材料となる日常の作業活動記録を管理
class CreateWorkLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :work_logs, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # 作業基本情報
      t.string :title, null: false, limit: 200
      t.text :description
      t.string :category, limit: 100
      t.string :project_name, limit: 100

      # 時間管理
      t.timestamp :started_at, null: false
      t.timestamp :ended_at
      # 継続時間は計算カラムとしてPostgreSQLで定義（Railsでは手動計算）

      # 評価スコア（1-5段階）
      t.integer :mood_score
      t.check_constraint 'mood_score >= 1 AND mood_score <= 5', 
                         name: 'check_work_logs_mood_score'
      
      t.integer :productivity_score
      t.check_constraint 'productivity_score >= 1 AND productivity_score <= 5', 
                         name: 'check_work_logs_productivity_score'
      
      t.integer :difficulty_score
      t.check_constraint 'difficulty_score >= 1 AND difficulty_score <= 5', 
                         name: 'check_work_logs_difficulty_score'

      # 分類・メモ機能
      t.text :tags, array: true, default: []
      t.text :notes
      t.string :location, limit: 100

      # ビジネス情報
      t.boolean :is_billable, default: false

      # ステータス管理
      t.string :status, default: 'completed', limit: 20
      t.check_constraint "status IN ('in_progress', 'completed', 'paused', 'cancelled')", 
                         name: 'check_work_logs_status'

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :work_logs, :started_at
    add_index :work_logs, :ended_at
    add_index :work_logs, :category
    add_index :work_logs, :project_name
    add_index :work_logs, :tags, using: :gin
    add_index :work_logs, :status
    add_index :work_logs, :is_billable
    add_index :work_logs, [:started_at, :ended_at]
  end
end 