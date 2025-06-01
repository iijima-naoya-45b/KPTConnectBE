# frozen_string_literal: true

# チャートテーブル作成マイグレーション
# ユーザーが作成・保存したチャート設定を管理
class CreateCharts < ActiveRecord::Migration[7.0]
  def change
    create_table :charts, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # チャート基本情報
      t.string :name, null: false, limit: 200
      t.text :description

      # チャート種類
      t.string :chart_type, null: false, limit: 50
      t.check_constraint "chart_type IN ('line', 'bar', 'pie', 'area', 'scatter', 'heatmap', 'treemap')", 
                         name: 'check_charts_type'

      # チャート設定（JSON形式）
      t.jsonb :config, null: false
      t.jsonb :data_query, null: false

      # 表示・管理設定
      t.boolean :is_public, default: false
      t.boolean :is_favorite, default: false
      t.integer :display_order, default: 0

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :charts, :chart_type
    add_index :charts, :is_favorite
    add_index :charts, :is_public
    add_index :charts, :display_order
    add_index :charts, :created_at
    add_index :charts, [:user_id, :chart_type]
    add_index :charts, [:user_id, :is_favorite]
    add_index :charts, [:user_id, :display_order]
  end
end 