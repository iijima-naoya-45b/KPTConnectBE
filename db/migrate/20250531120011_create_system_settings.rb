# frozen_string_literal: true

# システム設定テーブル作成マイグレーション
# アプリケーション全体の設定値を管理
class CreateSystemSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :system_settings, id: false do |t|
      # 設定キーを主キーとして使用
      t.string :key, primary_key: true, limit: 100

      # 設定値・説明
      t.text :value, null: false
      t.text :description

      # 公開設定（APIでの公開可否）
      t.boolean :is_public, default: false

      # 更新日時のみ（作成日時は不要）
      t.timestamp :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    # インデックス追加
    add_index :system_settings, :is_public
    add_index :system_settings, :updated_at

    # 初期データの挿入
    reversible do |dir|
      dir.up do
        # システム設定の初期値を挿入
        execute <<-SQL
          INSERT INTO system_settings (key, value, description, is_public) VALUES
          ('app_version', '1.0.0', 'アプリケーションバージョン', true),
          ('max_sessions_per_month_free', '10', '無料プランの月間最大セッション数', false),
          ('max_sessions_per_month_pro', '100', 'プロプランの月間最大セッション数', false),
          ('ai_analysis_enabled', 'true', 'AI分析機能の有効/無効', false),
          ('default_timezone', 'Asia/Tokyo', 'デフォルトタイムゾーン', true);
        SQL
      end
    end
  end
end 