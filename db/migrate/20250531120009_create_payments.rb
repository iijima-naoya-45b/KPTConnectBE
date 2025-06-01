# frozen_string_literal: true

# 支払いテーブル作成マイグレーション
# Stripe支払い履歴を管理
class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments, id: :uuid do |t|
      # 関連テーブルの外部キー（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer
      t.references :subscription, null: true, foreign_key: true, type: :uuid

      # Stripe関連情報
      t.string :stripe_payment_intent_id, null: false, limit: 255

      # 金額・通貨情報
      t.integer :amount, null: false  # セント単位
      t.string :currency, null: false, default: 'jpy', limit: 3

      # 支払い状態
      t.string :status, null: false, limit: 50
      t.check_constraint "status IN ('succeeded', 'pending', 'failed', 'canceled', 'requires_action')", 
                         name: 'check_payments_status'

      # 支払い方法・詳細情報
      t.string :payment_method_type, limit: 50
      t.text :description
      t.text :receipt_url
      t.string :invoice_id, limit: 255

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :status
    add_index :payments, :amount
    add_index :payments, :currency
    add_index :payments, :payment_method_type
    add_index :payments, :created_at
    add_index :payments, [:user_id, :status]
    add_index :payments, [:user_id, :created_at]
    add_index :payments, [:subscription_id, :created_at]
    add_index :payments, [:status, :created_at]
  end
end 