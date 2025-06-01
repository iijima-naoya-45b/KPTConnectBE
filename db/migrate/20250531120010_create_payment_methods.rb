# frozen_string_literal: true

# 支払い方法テーブル作成マイグレーション
# ユーザーが登録した支払い方法を管理
class CreatePaymentMethods < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_methods, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # Stripe関連情報
      t.string :stripe_payment_method_id, null: false, limit: 255

      # 支払い方法種類
      t.string :type, null: false, limit: 50
      t.check_constraint "type IN ('card', 'bank_account', 'sepa_debit')", 
                         name: 'check_payment_methods_type'

      # カード情報（表示用、セキュアな情報はStripeで管理）
      t.string :last4, limit: 4
      t.string :brand, limit: 50
      t.integer :exp_month
      t.check_constraint 'exp_month >= 1 AND exp_month <= 12', 
                         name: 'check_payment_methods_exp_month'
      t.integer :exp_year

      # 状態管理
      t.boolean :is_default, default: false
      t.boolean :is_active, default: true

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :payment_methods, :stripe_payment_method_id, unique: true
    add_index :payment_methods, :type
    add_index :payment_methods, :brand
    add_index :payment_methods, :is_default
    add_index :payment_methods, :is_active
    add_index :payment_methods, [:user_id, :is_default]
    add_index :payment_methods, [:user_id, :is_active]
    add_index :payment_methods, [:user_id, :type]
  end
end 