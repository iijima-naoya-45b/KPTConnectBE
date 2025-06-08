# frozen_string_literal: true

# ユーザー設定テーブル作成マイグレーション
# ユーザー個人の設定を柔軟に管理
class CreateUserSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :user_settings, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # 設定キー・値
      t.string :setting_key, null: false, limit: 100
      t.text :setting_value, null: false

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # 複合ユニークインデックス（ユーザーごとに同一キーは1つまで）
    add_index :user_settings, [ :user_id, :setting_key ],
              unique: true, name: 'index_user_settings_unique'

    # 個別インデックス
    add_index :user_settings, :setting_key
    add_index :user_settings, :created_at
  end
end
