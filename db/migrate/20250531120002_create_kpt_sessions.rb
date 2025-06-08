# frozen_string_literal: true

# KPTセッションテーブル作成マイグレーション
# 振り返り活動の単位となるセッション情報を管理
class CreateKptSessions < ActiveRecord::Migration[7.0]
  def change
    # テーブルが既に存在する場合はスキップ
    return if table_exists?(:kpt_sessions)
    
    create_table :kpt_sessions, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # セッション基本情報
      t.string :title, null: false, limit: 200
      t.text :description
      t.date :session_date, null: false, default: -> { 'CURRENT_DATE' }

      # ステータス管理
      t.string :status, default: 'draft', limit: 20
      t.check_constraint "status IN ('draft', 'in_progress', 'completed', 'archived')", 
                         name: 'check_kpt_sessions_status'

      # 分類・検索機能
      t.text :tags, array: true, default: []

      # テンプレート機能
      t.boolean :is_template, default: false
      t.string :template_name, limit: 100

      # 完了日時
      t.timestamp :completed_at

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加（既存チェック付き）
    add_index :kpt_sessions, :user_id unless index_exists?(:kpt_sessions, :user_id)
    add_index :kpt_sessions, :session_date unless index_exists?(:kpt_sessions, :session_date)
    add_index :kpt_sessions, :status unless index_exists?(:kpt_sessions, :status)
    add_index :kpt_sessions, :tags, using: :gin unless index_exists?(:kpt_sessions, :tags)
    add_index :kpt_sessions, :is_template unless index_exists?(:kpt_sessions, :is_template)
    add_index :kpt_sessions, :completed_at unless index_exists?(:kpt_sessions, :completed_at)
  end
end

class ChangeKptSessionsStatusToEnum < ActiveRecord::Migration[7.0]
  def up
    # 既存データをnot_startedに一括変換
    execute <<-SQL
      UPDATE kpt_sessions SET status = 'not_started';
    SQL

    # チェック制約を一旦削除（既存名が分からない場合はIF EXISTSで）
    execute <<-SQL
      ALTER TABLE kpt_sessions DROP CONSTRAINT IF EXISTS check_kpt_sessions_status;
    SQL

    # 新しいチェック制約を追加
    execute <<-SQL
      ALTER TABLE kpt_sessions
      ADD CONSTRAINT check_kpt_sessions_status
      CHECK (status IN ('not_started', 'in_progress', 'completed', 'pending'));
    SQL
  end

  def down
    # ダウングレード時はdraftに戻す（必要に応じて調整）
    execute <<-SQL
      UPDATE kpt_sessions SET status = 'draft';
    SQL
    execute <<-SQL
      ALTER TABLE kpt_sessions DROP CONSTRAINT IF EXISTS check_kpt_sessions_status;
    SQL
    execute <<-SQL
      ALTER TABLE kpt_sessions
      ADD CONSTRAINT check_kpt_sessions_status
      CHECK (status IN ('draft', 'in_progress', 'completed', 'archived'));
    SQL
  end
end 