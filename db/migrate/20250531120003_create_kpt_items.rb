# frozen_string_literal: true

# KPT項目テーブル作成マイグレーション
# Keep/Problem/Try各項目の詳細情報を管理
class CreateKptItems < ActiveRecord::Migration[7.0]
  def change
    create_table :kpt_items, id: :uuid do |t|
      # セッション関連付け
      t.references :kpt_session, null: false, foreign_key: true, type: :uuid

      # KPT項目の基本情報
      t.string :type, null: false, limit: 10
      t.check_constraint "type IN ('keep', 'problem', 'try')", 
                         name: 'check_kpt_items_type'
      t.text :content, null: false

      # 優先度・ステータス管理
      t.string :priority, default: 'medium', limit: 10
      t.check_constraint "priority IN ('low', 'medium', 'high')", 
                         name: 'check_kpt_items_priority'
      
      t.string :status, default: 'open', limit: 20
      t.check_constraint "status IN ('open', 'in_progress', 'completed', 'cancelled')", 
                         name: 'check_kpt_items_status'

      # 期日・担当者
      t.date :due_date
      t.string :assigned_to, limit: 100

      # 感情・影響度スコア（1-5段階）
      t.integer :emotion_score
      t.check_constraint 'emotion_score >= 1 AND emotion_score <= 5', 
                         name: 'check_kpt_items_emotion_score'
      
      t.integer :impact_score
      t.check_constraint 'impact_score >= 1 AND impact_score <= 5', 
                         name: 'check_kpt_items_impact_score'

      # 分類・メモ機能
      t.text :tags, array: true, default: []
      t.text :notes

      # 完了日時
      t.timestamp :completed_at

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :kpt_items, :type
    add_index :kpt_items, :status
    add_index :kpt_items, :priority
    add_index :kpt_items, :due_date
    add_index :kpt_items, :emotion_score
    add_index :kpt_items, :impact_score
    add_index :kpt_items, :tags, using: :gin
    add_index :kpt_items, :completed_at
  end
end 