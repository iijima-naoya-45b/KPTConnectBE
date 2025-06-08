# frozen_string_literal: true

# フィードバックテーブル作成マイグレーション
#
# @description ユーザーからのフィードバック情報を格納するテーブル
# helpページからの各種フィードバック（バグ報告、機能リクエスト等）を管理
class CreateFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :feedbacks do |t|
      # 外部キー
      t.references :user, null: false, foreign_key: true, comment: 'ユーザーID'
      t.references :feedback_type, null: false, foreign_key: true, comment: 'フィードバック種別ID'
      t.references :feedback_priority, null: false, foreign_key: true, comment: 'フィードバック優先度ID'

      # フィードバック内容
      t.string :title, null: false, limit: 255, comment: 'フィードバックタイトル'
      t.text :description, null: false, comment: 'フィードバック詳細説明'
      t.string :email, null: false, limit: 255, comment: 'フィードバック送信者メールアドレス'

      # 管理用カラム
      t.string :status, null: false, default: 'unread', limit: 50, comment: 'ステータス（unread/in_progress/resolved）'
      t.text :admin_notes, comment: '管理者メモ'
      t.datetime :resolved_at, comment: '解決日時'

      # メタデータ
      t.json :metadata, comment: '追加データ（ブラウザ情報、OS情報等）'

      # インデックス用
      t.boolean :is_active, null: false, default: true, comment: 'アクティブ状態'

      t.timestamps
    end

    # インデックス追加
    add_index :feedbacks, [ :user_id, :created_at ], name: 'index_feedbacks_on_user_and_created'
    add_index :feedbacks, [ :status, :created_at ], name: 'index_feedbacks_on_status_and_created'
    add_index :feedbacks, :feedback_type_id, name: 'index_feedbacks_on_type'
    add_index :feedbacks, :feedback_priority_id, name: 'index_feedbacks_on_priority'
  end
end
