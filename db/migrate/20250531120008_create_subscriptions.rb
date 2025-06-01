# frozen_string_literal: true

# サブスクリプションテーブル作成マイグレーション
# Stripeサブスクリプション情報を管理
class CreateSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :subscriptions, id: :uuid do |t|
      # ユーザー関連付け（既存usersテーブルのINTEGER IDを参照）
      t.references :user, null: false, foreign_key: true, type: :integer

      # Stripe関連情報
      t.string :stripe_subscription_id, null: false, limit: 255
      t.string :stripe_price_id, null: false, limit: 255

      # サブスクリプション状態
      t.string :status, null: false, limit: 50
      t.check_constraint "status IN ('active', 'canceled', 'incomplete', 'incomplete_expired', 'past_due', 'trialing', 'unpaid')", 
                         name: 'check_subscriptions_status'

      # 期間情報
      t.timestamp :current_period_start, null: false
      t.timestamp :current_period_end, null: false
      t.timestamp :trial_start
      t.timestamp :trial_end
      t.timestamp :canceled_at
      t.boolean :cancel_at_period_end, default: false

      # プラン情報
      t.string :plan_name, limit: 100
      t.string :billing_cycle, limit: 20
      t.check_constraint "billing_cycle IN ('monthly', 'yearly')", 
                         name: 'check_subscriptions_billing_cycle'

      # Rails標準のタイムスタンプ
      t.timestamps null: false
    end

    # インデックス追加
    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :stripe_price_id
    add_index :subscriptions, :status
    add_index :subscriptions, :current_period_end
    add_index :subscriptions, :plan_name
    add_index :subscriptions, :billing_cycle
    add_index :subscriptions, [:user_id, :status]
    add_index :subscriptions, [:status, :current_period_end]
  end
end 