# frozen_string_literal: true

# サブスクリプションAPIコントローラー
#
# @description サブスクリプション管理機能を提供
# Stripe連携による有料プラン管理、支払い履歴、プラン変更
#
# @endpoints
# - GET /api/v1/subscriptions 現在のサブスクリプション情報
# - POST /api/v1/subscriptions サブスクリプション作成
# - PUT /api/v1/subscriptions/:id サブスクリプション更新
# - DELETE /api/v1/subscriptions/:id サブスクリプションキャンセル
# - GET /api/v1/subscriptions/plans 利用可能プラン一覧
# - GET /api/v1/subscriptions/payments 支払い履歴
class Api::V1::SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription, only: [:show, :update, :destroy, :cancel]

  # 現在のサブスクリプション情報を取得
  # @route GET /api/v1/subscriptions
  # @response [JSON] サブスクリプション情報
  def index
    begin
      subscription = current_user.current_subscription
      subscription_data = subscription ? format_subscription_detail(subscription) : get_free_plan_info

      render json: {
        success: true,
        data: subscription_data,
        message: 'サブスクリプション情報を取得しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプション情報の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # サブスクリプションを作成
  # @route POST /api/v1/subscriptions
  # @param [String] price_id Stripeの価格ID
  # @param [String] payment_method_id 支払い方法ID
  # @response [JSON] 作成されたサブスクリプション
  def create
    begin
      price_id = params[:price_id]
      payment_method_id = params[:payment_method_id]

      if price_id.blank?
        render json: {
          success: false,
          error: '価格IDを指定してください'
        }, status: :unprocessable_entity
        return
      end

      # 既存のサブスクリプションがある場合はキャンセル
      current_subscription = current_user.current_subscription
      if current_subscription
        cancel_existing_subscription(current_subscription)
      end

      # Stripeでサブスクリプションを作成
      stripe_subscription = create_stripe_subscription(price_id, payment_method_id)
      
      # データベースに保存
      subscription = current_user.subscriptions.create!(
        stripe_subscription_id: stripe_subscription.id,
        stripe_price_id: price_id,
        status: stripe_subscription.status,
        current_period_start: Time.at(stripe_subscription.current_period_start),
        current_period_end: Time.at(stripe_subscription.current_period_end),
        plan_name: get_plan_name_from_price_id(price_id),
        billing_cycle: get_billing_cycle_from_price_id(price_id)
      )

      subscription_data = format_subscription_detail(subscription)

      render json: {
        success: true,
        data: subscription_data,
        message: 'サブスクリプションを作成しました'
      }, status: :created
    rescue Stripe::CardError => e
      render json: {
        success: false,
        error: 'カード決済エラー',
        details: e.message
      }, status: :payment_required
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプションの作成に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # サブスクリプション詳細を取得
  # @route GET /api/v1/subscriptions/:id
  # @response [JSON] サブスクリプション詳細
  def show
    begin
      subscription_data = format_subscription_detail(@subscription)

      render json: {
        success: true,
        data: subscription_data,
        message: 'サブスクリプション詳細を取得しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプション詳細の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # サブスクリプションを更新（プラン変更）
  # @route PUT /api/v1/subscriptions/:id
  # @param [String] new_price_id 新しい価格ID
  # @response [JSON] 更新されたサブスクリプション
  def update
    begin
      new_price_id = params[:new_price_id]

      if new_price_id.blank?
        render json: {
          success: false,
          error: '新しい価格IDを指定してください'
        }, status: :unprocessable_entity
        return
      end

      # Stripeでサブスクリプションを更新
      stripe_subscription = update_stripe_subscription(@subscription.stripe_subscription_id, new_price_id)

      # データベースを更新
      @subscription.update!(
        stripe_price_id: new_price_id,
        status: stripe_subscription.status,
        current_period_start: Time.at(stripe_subscription.current_period_start),
        current_period_end: Time.at(stripe_subscription.current_period_end),
        plan_name: get_plan_name_from_price_id(new_price_id),
        billing_cycle: get_billing_cycle_from_price_id(new_price_id)
      )

      subscription_data = format_subscription_detail(@subscription)

      render json: {
        success: true,
        data: subscription_data,
        message: 'サブスクリプションを更新しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプションの更新に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # サブスクリプションをキャンセル
  # @route DELETE /api/v1/subscriptions/:id
  # @param [Boolean] at_period_end 期間終了時にキャンセルするか
  # @response [JSON] キャンセル結果
  def destroy
    begin
      at_period_end = params[:at_period_end] != 'false'

      # Stripeでサブスクリプションをキャンセル
      stripe_subscription = cancel_stripe_subscription(@subscription.stripe_subscription_id, at_period_end)

      # データベースを更新
      update_params = {
        status: stripe_subscription.status,
        cancel_at_period_end: at_period_end
      }
      
      if stripe_subscription.canceled_at
        update_params[:canceled_at] = Time.at(stripe_subscription.canceled_at)
      end

      @subscription.update!(update_params)

      subscription_data = format_subscription_detail(@subscription)

      render json: {
        success: true,
        data: subscription_data,
        message: at_period_end ? '期間終了時にキャンセルします' : 'サブスクリプションをキャンセルしました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプションのキャンセルに失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 利用可能なプラン一覧を取得
  # @route GET /api/v1/subscriptions/plans
  # @response [JSON] プラン一覧
  def plans
    begin
      plans_data = get_available_plans

      render json: {
        success: true,
        data: {
          plans: plans_data,
          current_plan: current_user.current_subscription&.plan_name || 'Free'
        },
        message: '利用可能なプランを取得しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'プラン情報の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 支払い履歴を取得
  # @route GET /api/v1/subscriptions/payments
  # @param [Integer] page ページ番号
  # @param [Integer] per_page 1ページあたりの件数
  # @response [JSON] 支払い履歴
  def payments
    begin
      payments = current_user.payments.order(created_at: :desc)

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 20, 50].min

      total_count = payments.count
      payments = payments.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      payments_data = payments.map { |payment| format_payment_summary(payment) }

      render json: {
        success: true,
        data: {
          payments: payments_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          },
          summary: calculate_payment_summary(current_user.payments)
        },
        message: '支払い履歴を取得しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: '支払い履歴の取得に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  # サブスクリプションの再開
  # @route POST /api/v1/subscriptions/:id/resume
  # @response [JSON] 再開結果
  def resume
    begin
      if @subscription.status == 'canceled'
        render json: {
          success: false,
          error: 'キャンセル済みのサブスクリプションは再開できません'
        }, status: :unprocessable_entity
        return
      end

      # Stripeでサブスクリプションを再開
      stripe_subscription = resume_stripe_subscription(@subscription.stripe_subscription_id)

      @subscription.update!(
        status: stripe_subscription.status,
        cancel_at_period_end: false,
        canceled_at: nil
      )

      subscription_data = format_subscription_detail(@subscription)

      render json: {
        success: true,
        data: subscription_data,
        message: 'サブスクリプションを再開しました'
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'サブスクリプションの再開に失敗しました',
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # サブスクリプションを設定
  def set_subscription
    @subscription = current_user.subscriptions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'サブスクリプションが見つかりません'
    }, status: :not_found
  end

  # サブスクリプション詳細を整形
  # @param [Subscription] subscription サブスクリプション
  # @return [Hash] 整形されたサブスクリプションデータ
  def format_subscription_detail(subscription)
    {
      id: subscription.id,
      plan_name: subscription.plan_name,
      status: subscription.status,
      status_ja: subscription_status_ja(subscription.status),
      billing_cycle: subscription.billing_cycle,
      billing_cycle_ja: billing_cycle_ja(subscription.billing_cycle),
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      trial_start: subscription.trial_start,
      trial_end: subscription.trial_end,
      canceled_at: subscription.canceled_at,
      cancel_at_period_end: subscription.cancel_at_period_end,
      features: get_plan_features(subscription.plan_name),
      next_payment_date: get_next_payment_date(subscription),
      days_until_renewal: calculate_days_until_renewal(subscription),
      created_at: subscription.created_at,
      updated_at: subscription.updated_at
    }
  end

  # 支払い情報を整形
  # @param [Payment] payment 支払い
  # @return [Hash] 整形された支払いデータ
  def format_payment_summary(payment)
    {
      id: payment.id,
      amount: payment.amount,
      amount_formatted: format_amount(payment.amount, payment.currency),
      currency: payment.currency,
      status: payment.status,
      status_ja: payment_status_ja(payment.status),
      payment_method_type: payment.payment_method_type,
      description: payment.description,
      receipt_url: payment.receipt_url,
      invoice_id: payment.invoice_id,
      created_at: payment.created_at
    }
  end

  # フリープラン情報を取得
  # @return [Hash] フリープラン情報
  def get_free_plan_info
    {
      plan_name: 'Free',
      status: 'active',
      status_ja: 'アクティブ',
      billing_cycle: nil,
      features: get_plan_features('Free'),
      upgrade_available: true,
      recommended_plan: 'Pro'
    }
  end

  # 利用可能なプランを取得
  # @return [Array] プラン情報の配列
  def get_available_plans
    [
      {
        name: 'Free',
        display_name: 'フリープラン',
        price: 0,
        currency: 'jpy',
        billing_cycle: nil,
        stripe_price_id: nil,
        features: get_plan_features('Free'),
        recommended: false
      },
      {
        name: 'Basic',
        display_name: 'ベーシックプラン',
        price: 980,
        currency: 'jpy',
        billing_cycle: 'monthly',
        stripe_price_id: 'price_basic_monthly',
        features: get_plan_features('Basic'),
        recommended: false
      },
      {
        name: 'Pro',
        display_name: 'プロプラン',
        price: 1980,
        currency: 'jpy',
        billing_cycle: 'monthly',
        stripe_price_id: 'price_pro_monthly',
        features: get_plan_features('Pro'),
        recommended: true
      },
      {
        name: 'Pro',
        display_name: 'プロプラン（年間）',
        price: 19800,
        currency: 'jpy',
        billing_cycle: 'yearly',
        stripe_price_id: 'price_pro_yearly',
        features: get_plan_features('Pro'),
        recommended: false,
        discount: '2ヶ月分お得'
      }
    ]
  end

  # プラン機能を取得
  # @param [String] plan_name プラン名
  # @return [Array] 機能リスト
  def get_plan_features(plan_name)
    case plan_name
    when 'Free'
      [
        '月5セッションまで',
        '基本的なKPT機能',
        'コミュニティサポート',
        '簡易レポート'
      ]
    when 'Basic'
      [
        '月20セッションまで',
        '全KPT機能',
        'メールサポート',
        '詳細レポート',
        'データエクスポート',
        'カスタムタグ'
      ]
    when 'Pro'
      [
        '無制限セッション',
        '全機能利用可能',
        '優先サポート',
        'AI分析・インサイト',
        '高度なレポート',
        'チーム機能',
        'API アクセス',
        'カスタムダッシュボード'
      ]
    else
      []
    end
  end

  # 支払いサマリーを計算
  # @param [ActiveRecord::Relation] payments 支払いクエリ
  # @return [Hash] 支払いサマリー
  def calculate_payment_summary(payments)
    {
      total_amount: payments.where(status: 'succeeded').sum(:amount),
      total_payments: payments.count,
      successful_payments: payments.where(status: 'succeeded').count,
      failed_payments: payments.where(status: 'failed').count,
      last_payment_date: payments.where(status: 'succeeded').maximum(:created_at)
    }
  end

  # Stripe サブスクリプション作成
  def create_stripe_subscription(price_id, payment_method_id)
    # 実際の実装では Stripe API を使用
    # ここは仮の実装
    OpenStruct.new(
      id: "sub_#{SecureRandom.hex(12)}",
      status: 'active',
      current_period_start: Time.current.to_i,
      current_period_end: 1.month.from_now.to_i
    )
  end

  # Stripe サブスクリプション更新
  def update_stripe_subscription(subscription_id, new_price_id)
    # 実際の実装では Stripe API を使用
    OpenStruct.new(
      id: subscription_id,
      status: 'active',
      current_period_start: Time.current.to_i,
      current_period_end: 1.month.from_now.to_i
    )
  end

  # Stripe サブスクリプションキャンセル
  def cancel_stripe_subscription(subscription_id, at_period_end)
    # 実際の実装では Stripe API を使用
    OpenStruct.new(
      id: subscription_id,
      status: at_period_end ? 'active' : 'canceled',
      canceled_at: at_period_end ? nil : Time.current.to_i
    )
  end

  # Stripe サブスクリプション再開
  def resume_stripe_subscription(subscription_id)
    # 実際の実装では Stripe API を使用
    OpenStruct.new(
      id: subscription_id,
      status: 'active'
    )
  end

  # 既存サブスクリプションをキャンセル
  def cancel_existing_subscription(subscription)
    cancel_stripe_subscription(subscription.stripe_subscription_id, false)
    subscription.update!(status: 'canceled', canceled_at: Time.current)
  end

  # 価格IDからプラン名を取得
  def get_plan_name_from_price_id(price_id)
    case price_id
    when 'price_basic_monthly'
      'Basic'
    when 'price_pro_monthly', 'price_pro_yearly'
      'Pro'
    else
      'Unknown'
    end
  end

  # 価格IDから請求サイクルを取得
  def get_billing_cycle_from_price_id(price_id)
    price_id.include?('yearly') ? 'yearly' : 'monthly'
  end

  # 次回支払い日を取得
  def get_next_payment_date(subscription)
    return nil if subscription.status == 'canceled'
    subscription.current_period_end
  end

  # 更新までの日数を計算
  def calculate_days_until_renewal(subscription)
    return nil if subscription.status == 'canceled'
    (subscription.current_period_end.to_date - Date.current).to_i
  end

  # 金額をフォーマット
  def format_amount(amount, currency)
    case currency
    when 'jpy'
      "¥#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    when 'usd'
      "$#{(amount / 100.0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    else
      "#{amount} #{currency.upcase}"
    end
  end

  # ステータス名の日本語変換
  def subscription_status_ja(status)
    case status
    when 'active'
      'アクティブ'
    when 'canceled'
      'キャンセル済み'
    when 'incomplete'
      '未完了'
    when 'incomplete_expired'
      '期限切れ'
    when 'past_due'
      '支払い期限超過'
    when 'trialing'
      'トライアル中'
    when 'unpaid'
      '未払い'
    else
      status
    end
  end

  def billing_cycle_ja(cycle)
    case cycle
    when 'monthly'
      '月額'
    when 'yearly'
      '年額'
    else
      cycle
    end
  end

  def payment_status_ja(status)
    case status
    when 'succeeded'
      '成功'
    when 'pending'
      '処理中'
    when 'failed'
      '失敗'
    when 'canceled'
      'キャンセル'
    when 'requires_action'
      '認証必要'
    else
      status
    end
  end
end 