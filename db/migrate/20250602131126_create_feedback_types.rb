# frozen_string_literal: true

# フィードバック種別マスターテーブル作成マイグレーション
#
# @description フィードバックの種別を管理するマスターテーブル
# フロントエンドの選択肢と連携して文言を一元管理
class CreateFeedbackTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_types do |t|
      # 基本情報
      t.string :name, null: false, limit: 100, comment: 'フィードバック種別名'
      t.string :key, null: false, limit: 50, comment: 'フィードバック種別キー（システム内部用）'
      t.text :description, comment: 'フィードバック種別説明'
      
      # 表示制御
      t.integer :display_order, null: false, default: 0, comment: '表示順序'
      t.boolean :is_active, null: false, default: true, comment: 'アクティブ状態'
      
      # 管理用
      t.string :color_code, limit: 7, comment: '表示用カラーコード（#FFFFFF形式）'
      t.string :icon_name, limit: 50, comment: 'アイコン名'

      t.timestamps
    end

    # インデックス追加
    add_index :feedback_types, :key, unique: true, name: 'index_feedback_types_on_key'
    add_index :feedback_types, [:is_active, :display_order], name: 'index_feedback_types_on_active_and_order'

    # 初期データ挿入
    reversible do |dir|
      dir.up do
        # フロントエンドのFeedbackForm.tsxで定義されている値と同期
        execute <<-SQL
          INSERT INTO feedback_types (name, key, description, display_order, color_code, icon_name, created_at, updated_at) VALUES
          ('バグ報告', 'bug', 'アプリケーションの不具合や予期しない動作について報告', 1, '#ef4444', 'bug', NOW(), NOW()),
          ('機能リクエスト', 'feature', '新しい機能の追加や既存機能の拡張について提案', 2, '#3b82f6', 'lightbulb', NOW(), NOW()),
          ('改善提案', 'improvement', 'ユーザビリティやパフォーマンスの改善について提案', 3, '#10b981', 'arrow-up', NOW(), NOW()),
          ('その他', 'other', '上記以外のフィードバックや質問', 4, '#6b7280', 'question-mark', NOW(), NOW());
        SQL
      end
      
      dir.down do
        execute "DELETE FROM feedback_types WHERE key IN ('bug', 'feature', 'improvement', 'other');"
      end
    end
  end
end
