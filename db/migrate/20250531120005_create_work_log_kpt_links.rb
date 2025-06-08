# frozen_string_literal: true

# 作業ログ-KPT関連付けテーブル作成マイグレーション
# 作業ログとKPTセッションの多対多関係を管理
class CreateWorkLogKptLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :work_log_kpt_links, id: :uuid do |t|
      # 関連テーブルの外部キー
      t.references :work_log, null: false, foreign_key: true, type: :uuid
      t.references :kpt_session, null: false, foreign_key: true, type: :uuid

      # 関連の質を示すスコア
      t.integer :relevance_score
      t.check_constraint 'relevance_score >= 1 AND relevance_score <= 5',
                         name: 'check_work_log_kpt_links_relevance_score'

      # 関連付けの理由・メモ
      t.text :notes

      # 作成日時（更新は基本的に想定しない）
      t.timestamp :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end

    # 複合ユニークインデックス（同じ組み合わせの重複防止）
    add_index :work_log_kpt_links, [ :work_log_id, :kpt_session_id ],
              unique: true, name: 'index_work_log_kpt_links_unique'

    # 個別インデックス
    add_index :work_log_kpt_links, :relevance_score
    add_index :work_log_kpt_links, :created_at
  end
end
