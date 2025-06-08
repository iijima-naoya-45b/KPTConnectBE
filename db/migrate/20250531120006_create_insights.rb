# frozen_string_literal: true

# インサイトテーブル作成マイグレーション
# AI分析による振り返りサマリ・メタ情報を管理
class CreateInsights < ActiveRecord::Migration[7.0]
  def change
    create_table :insights, id: :uuid do |t|
      # 関連テーブルの外部キー
      t.references :kpt_session, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :integer

      # インサイトの種類
      t.string :insight_type, null: false, limit: 50
      t.check_constraint "insight_type IN ('summary', 'sentiment', 'trend', 'recommendation', 'pattern')",
                         name: 'check_insights_type'

      # インサイト基本情報
      t.string :title, null: false, limit: 200
      t.jsonb :content, null: false
      t.decimal :confidence_score, precision: 3, scale: 2
      t.check_constraint 'confidence_score >= 0 AND confidence_score <= 1',
                         name: 'check_insights_confidence_score'

      # データソース・メタデータ
      t.string :data_source, default: 'ai_analysis', limit: 50
      t.jsonb :metadata

      # 状態管理
      t.boolean :is_active, default: true

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :insights, :insight_type
    add_index :insights, :content, using: :gin
    add_index :insights, :confidence_score
    add_index :insights, :data_source
    add_index :insights, :is_active
    add_index :insights, :created_at
    add_index :insights, [ :user_id, :insight_type ]
    add_index :insights, [ :kpt_session_id, :insight_type ]
  end
end
