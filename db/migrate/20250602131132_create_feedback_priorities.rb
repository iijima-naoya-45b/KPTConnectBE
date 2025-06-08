# frozen_string_literal: true

# フィードバック優先度マスターテーブル作成マイグレーション
#
# @description フィードバックの優先度を管理するマスターテーブル
# フロントエンドの選択肢と連携して文言を一元管理
class CreateFeedbackPriorities < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_priorities do |t|
      # 基本情報
      t.string :name, null: false, limit: 100, comment: 'フィードバック優先度名'
      t.string :key, null: false, limit: 50, comment: 'フィードバック優先度キー（システム内部用）'
      t.text :description, comment: 'フィードバック優先度説明'

      # 表示制御
      t.integer :display_order, null: false, default: 0, comment: '表示順序'
      t.integer :priority_level, null: false, default: 1, comment: '優先度レベル（数値が大きいほど高優先度）'
      t.boolean :is_active, null: false, default: true, comment: 'アクティブ状態'

      # 管理用
      t.string :color_code, limit: 7, comment: '表示用カラーコード（#FFFFFF形式）'
      t.string :badge_class, limit: 100, comment: 'CSSバッジクラス名'

      t.timestamps
    end

    # インデックス追加
    add_index :feedback_priorities, :key, unique: true, name: 'index_feedback_priorities_on_key'
    add_index :feedback_priorities, [ :is_active, :display_order ], name: 'index_feedback_priorities_on_active_and_order'
    add_index :feedback_priorities, :priority_level, name: 'index_feedback_priorities_on_level'

    # 初期データ挿入
    reversible do |dir|
      dir.up do
        # フロントエンドのFeedbackForm.tsxで定義されている値と同期
        execute <<-SQL
          INSERT INTO feedback_priorities (name, key, description, display_order, priority_level, color_code, badge_class, created_at, updated_at) VALUES
          ('低', 'low', '軽微な問題や改善提案。時間のある時に対応', 1, 1, '#6b7280', 'bg-gray-100 text-gray-800', NOW(), NOW()),
          ('中', 'medium', '一般的な問題や機能リクエスト。通常の優先度で対応', 2, 2, '#f59e0b', 'bg-yellow-100 text-yellow-800', NOW(), NOW()),
          ('高', 'high', '重要な問題や緊急性のある機能。優先的に対応が必要', 3, 3, '#ef4444', 'bg-red-100 text-red-800', NOW(), NOW());
        SQL
      end

      dir.down do
        execute "DELETE FROM feedback_priorities WHERE key IN ('low', 'medium', 'high');"
      end
    end
  end
end
