# frozen_string_literal: true

# ユーザーモデル
#
# @description ユーザー認証とKPT機能のメインモデル
# OAuth認証、KPTセッション管理、ユーザー統計機能を提供
#
# @attr [String] email メールアドレス
# @attr [String] username ユーザー名
# @attr [String] provider OAuth認証プロバイダー
# @attr [String] uid OAuth認証UID
# @attr [String] name 表示名
# @attr [String] avatar_url アバターURL
# @attr [String] stripe_customer_id Stripe顧客ID
# @attr [String] timezone タイムゾーン
# @attr [String] language 言語設定
# @attr [Boolean] is_active アクティブ状態
# @attr [DateTime] email_verified_at メール認証日時
# @attr [DateTime] last_login_at 最終ログイン日時
class User < ApplicationRecord
  authenticates_with_sorcery!

  # リレーション
  has_many :authentications, dependent: :destroy
  has_many :kpt_sessions, dependent: :destroy
  has_many :kpt_items, through: :kpt_sessions
  has_many :insights, dependent: :destroy
  has_many :work_logs, dependent: :destroy
  has_many :charts, dependent: :destroy
  has_many :user_settings, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_many :reflection_marks, dependent: :destroy
  has_many :goals

  # バリデーション
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :language, inclusion: { in: %w[ja en] }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_kpt_activity, -> { joins(:kpt_sessions).distinct }

  # インスタンスメソッド

  # フルネームまたは表示名を取得
  # @return [String] 表示用名前
  def display_name
    email.split("@").first
  end

  # 管理者かどうかをチェック
  # @return [Boolean] 管理者状態
  def admin?
    # 現在はemail属性で判定（将来的にはroleカラム等に変更可能）
    %w[admin@kptconnect.com support@kptconnect.com].include?(email.downcase)
  end

  # アクティブかどうかをチェック
  # @return [Boolean] アクティブ状態
  def is_active?
    is_active
  end

  # アクティブなKPTセッション数を取得
  # @return [Integer] アクティブセッション数
  def active_kpt_sessions_count
    kpt_sessions.active.count
  end

  # 完了済みKPTセッション数を取得
  # @return [Integer] 完了セッション数
  def completed_kpt_sessions_count
    kpt_sessions.completed.count
  end

  # 今月のKPTアクティビティ統計を取得
  # @return [Hash] 今月の統計データ
  def monthly_kpt_stats
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month

    sessions = kpt_sessions.by_date_range(start_date, end_date)
    items = kpt_items.joins(:kpt_session)
                     .where(kpt_sessions: { session_date: start_date..end_date })

    {
      sessions_count: sessions.count,
      completed_sessions: sessions.completed.count,
      total_items: items.count,
      completed_items: items.completed.count,
      keep_items: items.keeps.count,
      problem_items: items.problems.count,
      try_items: items.tries.count,
      average_emotion_score: items.with_emotion_score.average(:emotion_score)&.round(2),
      average_impact_score: items.with_impact_score.average(:impact_score)&.round(2)
    }
  end

  # KPTアクティビティの概要統計を取得
  # @return [Hash] 概要統計データ
  def kpt_overview_stats
    {
      total_sessions: kpt_sessions.count,
      completed_sessions: kpt_sessions.completed.count,
      total_items: kpt_items.count,
      completed_items: kpt_items.completed.count,
      active_items: kpt_items.active.count,
      overdue_items: kpt_items.overdue.count,
      recent_activity: recent_kpt_activity
    }
  end

  # 最近のKPTアクティビティを取得
  # @param [Integer] limit 取得件数
  # @return [Array] 最近のアクティビティ
  def recent_kpt_activity(limit = 10)
    activities = []

    # 最近のセッション
    recent_sessions = kpt_sessions.recent.limit(5)
    recent_sessions.each do |session|
      activities << {
        type: "session",
        action: session.completed? ? "completed" : "created",
        object: session,
        timestamp: session.completed? ? session.completed_at : session.created_at
      }
    end

    # 最近完了したアイテム
    recent_items = kpt_items.completed.order(completed_at: :desc).limit(5)
    recent_items.each do |item|
      activities << {
        type: "item",
        action: "completed",
        object: item,
        timestamp: item.completed_at
      }
    end

    # タイムスタンプでソートして制限数まで返す
    activities.sort_by { |a| a[:timestamp] }
             .reverse
             .first(limit)
  end

  # ダッシュボード用サマリーデータを取得
  # @return [Hash] ダッシュボードサマリー
  def dashboard_summary
    {
      user: {
        display_name: display_name,
        avatar_url: avatar_url,
        member_since: created_at.strftime("%Y年%m月"),
        timezone: timezone
      },
      activity: {
        total_sessions: kpt_sessions.count,
        this_month_sessions: kpt_sessions.by_date_range(Date.current.beginning_of_month, Date.current.end_of_month).count,
        completion_rate: calculate_completion_rate,
        streak_days: calculate_streak_days
      },
      items: {
        total: kpt_items.count,
        active: kpt_items.active.count,
        completed_this_week: kpt_items.completed.where("completed_at >= ?", 1.week.ago).count,
        overdue: kpt_items.overdue.count
      },
      insights: {
        popular_tags: KptItem.popular_tags(self, nil, 5),
        emotion_trend: KptItem.emotion_trend(self, 7),
        recent_activity: recent_kpt_activity(5)
      }
    }
  end

  # ユーザー設定を取得
  # @param [String] key 設定キー
  # @param [String] default_value デフォルト値
  # @return [String] 設定値
  def get_setting(key, default_value = nil)
    setting = user_settings.find_by(setting_key: key)
    setting&.setting_value || default_value
  end

  # ユーザー設定を更新
  # @param [String] key 設定キー
  # @param [String] value 設定値
  def set_setting(key, value)
    setting = user_settings.find_or_initialize_by(setting_key: key)
    setting.setting_value = value.to_s
    setting.save!
  end

  # Slack通知が有効かどうかをチェック
  # @return [Boolean] Slack通知の有効状態
  def slack_notification_enabled?
    slack_notification_enabled
  end

  # Slack通知設定を更新
  # @param [Boolean] enabled 有効状態
  # @param [String] webhook_url Webhook URL
  def update_slack_notification_settings(enabled:, webhook_url: nil)
    update(
      slack_notification_enabled: enabled,
      slack_webhook_url: webhook_url
    )
  end

  # 現在のサブスクリプションを取得
  # @return [Subscription, nil] アクティブなサブスクリプション
  def current_subscription
    subscriptions.where(status: [ "active", "trialing", "past_due" ]).order(created_at: :desc).first
  end

  # プロプランかどうか
  # @return [Boolean] プロプランユーザーかどうか
  def pro_plan?
    current_subscription&.plan_name == "Pro"
  end

  private

  # 完了率を計算
  # @return [Float] 完了率 (0.0-1.0)
  def calculate_completion_rate
    total = kpt_sessions.count
    return 0.0 if total.zero?

    completed = kpt_sessions.completed.count
    completed.to_f / total
  end

  # 連続日数を計算
  # @return [Integer] 連続KPT実行日数
  def calculate_streak_days
    dates = kpt_sessions.where("session_date >= ?", 30.days.ago)
                       .order(session_date: :desc)
                       .pluck(:session_date)
                       .uniq

    return 0 if dates.empty?

    streak = 0
    current_date = Date.current

    dates.each do |date|
      if date == current_date
        streak += 1
        current_date -= 1.day
      else
        break
      end
    end

    streak
  end
end
