# frozen_string_literal: true

# 振り返りマークテーブル作成マイグレーション
#
# @description 個人振り返りカレンダーの日付マーク機能用テーブル
class CreateReflectionMarks < ActiveRecord::Migration[8.0]
  def change
    # usersテーブルが存在するかチェック
    return unless table_exists?(:users)
    
    # reflection_marksテーブルが既に存在するかチェック
    return if table_exists?(:reflection_marks)
    
    create_table :reflection_marks do |t|
      t.references :user, null: false, foreign_key: true, comment: 'ユーザーID'
      t.date :date, null: false, comment: 'マークした日付'
      t.string :note, limit: 500, comment: 'メモ'
      t.string :mark_type, default: 'reflection', null: false, comment: 'マークタイプ'
      t.json :metadata, comment: '追加データ（JSON）'

      t.timestamps
    end

    # インデックス
    add_index :reflection_marks, [ :user_id, :date ], unique: true, name: 'index_reflection_marks_on_user_and_date'
    add_index :reflection_marks, :date, name: 'index_reflection_marks_on_date'
    add_index :reflection_marks, :mark_type, name: 'index_reflection_marks_on_mark_type'
    add_index :reflection_marks, :created_at, name: 'index_reflection_marks_on_created_at'
  end
end
