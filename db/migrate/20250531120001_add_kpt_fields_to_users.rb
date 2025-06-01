# frozen_string_literal: true

# 既存usersテーブルにKPTアプリ用カラム追加マイグレーション
# Stripe連携、個人設定、アカウント状態管理カラムを追加
class AddKptFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    # nameカラムは既に存在するためスキップ
    # add_column :users, :name, :string, limit: 100
    
    add_column :users, :avatar_url, :text unless column_exists?(:users, :avatar_url)
    
    # Stripe連携情報
    add_column :users, :stripe_customer_id, :string, limit: 255 unless column_exists?(:users, :stripe_customer_id)
    
    # 地域・言語設定
    add_column :users, :timezone, :string, default: 'Asia/Tokyo', limit: 50 unless column_exists?(:users, :timezone)
    add_column :users, :language, :string, default: 'ja', limit: 10 unless column_exists?(:users, :language)
    
    # アカウント状態管理
    add_column :users, :is_active, :boolean, default: true unless column_exists?(:users, :is_active)
    add_column :users, :email_verified_at, :timestamp unless column_exists?(:users, :email_verified_at)
    add_column :users, :last_login_at, :timestamp unless column_exists?(:users, :last_login_at)
    
    # インデックス追加（既存チェックをしてから追加）
    unless index_exists?(:users, :stripe_customer_id)
      add_index :users, :stripe_customer_id, unique: true, where: 'stripe_customer_id IS NOT NULL'
    end
    
    unless index_exists?(:users, :is_active)
      add_index :users, :is_active
    end
  end
end 