# frozen_string_literal: true

# 通知APIコントローラー
class Api::V1::NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [ :show, :update, :destroy, :read ]

  # 通知一覧を取得
  def index
    begin
      notifications = current_user.notifications.order(created_at: :desc)

      # フィルター適用
      notifications = notifications.where(notification_type: params[:type]) if params[:type].present?
      notifications = notifications.where(is_read: params[:is_read] == "true") if params[:is_read].present?
      notifications = notifications.where(priority: params[:priority]) if params[:priority].present?

      # ページネーション
      page = params[:page]&.to_i || 1
      per_page = [ params[:per_page]&.to_i || 20, 100 ].min

      total_count = notifications.count
      notifications = notifications.offset((page - 1) * per_page).limit(per_page)

      # データ整形
      notifications_data = notifications.map { |notification| format_notification_summary(notification) }

      render json: {
        success: true,
        data: {
          notifications: notifications_data,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
            total_count: total_count
          },
          summary: {
            unread_count: current_user.notifications.unread.count,
            today_count: current_user.notifications.where("created_at >= ?", Date.current.beginning_of_day).count,
            priority_counts: current_user.notifications.group(:priority).count
          }
        },
        message: "通知一覧を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知一覧の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知詳細を取得
  def show
    begin
      # 通知を自動的に既読にする
      @notification.update!(is_read: true, read_at: Time.current) unless @notification.is_read?

      notification_data = format_notification_detail(@notification)

      render json: {
        success: true,
        data: notification_data,
        message: "通知詳細を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知詳細の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知を既読にする
  def read
    begin
      if @notification.update(is_read: true, read_at: Time.current)
        render json: {
          success: true,
          data: format_notification_summary(@notification),
          message: "通知を既読にしました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "通知の既読処理に失敗しました",
          details: @notification.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "既読処理中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 全ての通知を既読にする
  def mark_all_read
    begin
      updated_count = current_user.notifications.unread.update_all(
        is_read: true,
        read_at: Time.current,
        updated_at: Time.current
      )

      render json: {
        success: true,
        data: {
          updated_count: updated_count,
          remaining_unread: current_user.notifications.unread.count
        },
        message: "#{updated_count}件の通知を既読にしました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "一括既読処理に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知を削除
  def destroy
    begin
      if @notification.destroy
        render json: {
          success: true,
          message: "通知を削除しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "通知の削除に失敗しました",
          details: @notification.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知削除中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知設定を取得
  def settings
    begin
      settings_data = {
        email_notifications: format_email_notification_settings,
        push_notifications: format_push_notification_settings,
        in_app_notifications: format_in_app_notification_settings,
        frequency_settings: format_frequency_settings,
        quiet_hours: format_quiet_hours_settings
      }

      render json: {
        success: true,
        data: settings_data,
        message: "通知設定を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知設定の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知設定を更新
  def update_settings
    begin
      updated_settings = {}
      errors = []

      # 各設定カテゴリを更新
      if params[:email_notifications].present?
        update_email_notification_settings(params[:email_notifications])
        updated_settings[:email_notifications] = format_email_notification_settings
      end

      if params[:push_notifications].present?
        update_push_notification_settings(params[:push_notifications])
        updated_settings[:push_notifications] = format_push_notification_settings
      end

      if params[:in_app_notifications].present?
        update_in_app_notification_settings(params[:in_app_notifications])
        updated_settings[:in_app_notifications] = format_in_app_notification_settings
      end

      if params[:frequency_settings].present?
        update_frequency_settings(params[:frequency_settings])
        updated_settings[:frequency_settings] = format_frequency_settings
      end

      if params[:quiet_hours].present?
        update_quiet_hours_settings(params[:quiet_hours])
        updated_settings[:quiet_hours] = format_quiet_hours_settings
      end

      render json: {
        success: true,
        data: updated_settings,
        message: "通知設定を更新しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知設定の更新に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # テスト通知を送信
  def test
    begin
      notification_type = params[:type] || "test"

      notification = current_user.notifications.create!(
        notification_type: "system",
        title: "テスト通知",
        message: "これはテスト通知です。通知機能が正常に動作しています。",
        priority: "normal",
        is_read: false,
        action_url: "/dashboard",
        metadata: {
          test: true,
          sent_at: Time.current.iso8601
        }
      )

      # 実際の実装では、ここでプッシュ通知やメール送信を行う
      send_push_notification(notification) if should_send_push_notification?("system")
      send_email_notification(notification) if should_send_email_notification?("system")

      render json: {
        success: true,
        data: format_notification_detail(notification),
        message: "テスト通知を送信しました"
      }, status: :created
    rescue StandardError => e
      render json: {
        success: false,
        error: "テスト通知の送信に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # 通知統計を取得
  def stats
    begin
      days = params[:days]&.to_i || 30
      start_date = days.days.ago

      notifications = current_user.notifications.where("created_at >= ?", start_date)

      stats_data = {
        period: {
          days: days,
          start_date: start_date,
          end_date: Time.current
        },
        summary: {
          total_notifications: notifications.count,
          unread_notifications: notifications.unread.count,
          read_rate: calculate_read_rate(notifications),
          average_response_time: calculate_average_response_time(notifications)
        },
        by_type: notifications.group(:notification_type).count,
        by_priority: notifications.group(:priority).count,
        daily_trends: generate_daily_notification_trends(notifications, start_date)
      }

      render json: {
        success: true,
        data: stats_data,
        message: "通知統計を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "通知統計の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # 通知を設定
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: "通知が見つかりません"
    }, status: :not_found
  end

  # 通知サマリーを整形
  def format_notification_summary(notification)
    {
      id: notification.id,
      type: notification.notification_type,
      title: notification.title,
      message: notification.message&.truncate(100),
      priority: notification.priority,
      priority_ja: priority_name_ja(notification.priority),
      is_read: notification.is_read,
      read_at: notification.read_at,
      action_url: notification.action_url,
      created_at: notification.created_at,
      time_ago: time_ago_in_words(notification.created_at)
    }
  end

  # 通知詳細を整形
  def format_notification_detail(notification)
    {
      id: notification.id,
      type: notification.notification_type,
      type_ja: notification_type_ja(notification.notification_type),
      title: notification.title,
      message: notification.message,
      priority: notification.priority,
      priority_ja: priority_name_ja(notification.priority),
      is_read: notification.is_read,
      read_at: notification.read_at,
      action_url: notification.action_url,
      metadata: notification.metadata,
      expires_at: notification.expires_at,
      created_at: notification.created_at,
      updated_at: notification.updated_at
    }
  end

  # メール通知設定を整形
  def format_email_notification_settings
    {
      enabled: current_user.get_setting("email_notifications_enabled", "true") == "true",
      kpt_session_completed: current_user.get_setting("email_kpt_session_completed", "true") == "true",
      weekly_summary: current_user.get_setting("email_weekly_summary", "true") == "true",
      item_reminders: current_user.get_setting("email_item_reminders", "true") == "true",
      system_updates: current_user.get_setting("email_system_updates", "false") == "true",
      marketing: current_user.get_setting("email_marketing", "false") == "true"
    }
  end

  # プッシュ通知設定を整形
  def format_push_notification_settings
    {
      enabled: current_user.get_setting("push_notifications_enabled", "true") == "true",
      browser_enabled: current_user.get_setting("push_browser_enabled", "true") == "true",
      kpt_reminders: current_user.get_setting("push_kpt_reminders", "true") == "true",
      item_due_alerts: current_user.get_setting("push_item_due_alerts", "true") == "true",
      achievement_alerts: current_user.get_setting("push_achievement_alerts", "true") == "true"
    }
  end

  # アプリ内通知設定を整形
  def format_in_app_notification_settings
    {
      enabled: current_user.get_setting("in_app_notifications_enabled", "true") == "true",
      show_badge: current_user.get_setting("in_app_show_badge", "true") == "true",
      auto_read_time: current_user.get_setting("in_app_auto_read_time", "0").to_i,
      sound_enabled: current_user.get_setting("in_app_sound_enabled", "true") == "true"
    }
  end

  # 頻度設定を整形
  def format_frequency_settings
    {
      daily_digest_time: current_user.get_setting("daily_digest_time", "09:00"),
      weekly_summary_day: current_user.get_setting("weekly_summary_day", "1").to_i,
      reminder_frequency: current_user.get_setting("reminder_frequency", "daily"),
      max_notifications_per_day: current_user.get_setting("max_notifications_per_day", "10").to_i
    }
  end

  # 通知停止時間設定を整形
  def format_quiet_hours_settings
    {
      enabled: current_user.get_setting("quiet_hours_enabled", "false") == "true",
      start_time: current_user.get_setting("quiet_hours_start", "22:00"),
      end_time: current_user.get_setting("quiet_hours_end", "08:00"),
      timezone: current_user.timezone || "Asia/Tokyo"
    }
  end

  # 各設定更新メソッド
  def update_email_notification_settings(settings)
    settings.each do |key, value|
      current_user.set_setting("email_#{key}", value.to_s)
    end
  end

  def update_push_notification_settings(settings)
    settings.each do |key, value|
      current_user.set_setting("push_#{key}", value.to_s)
    end
  end

  def update_in_app_notification_settings(settings)
    settings.each do |key, value|
      current_user.set_setting("in_app_#{key}", value.to_s)
    end
  end

  def update_frequency_settings(settings)
    settings.each do |key, value|
      current_user.set_setting(key, value.to_s)
    end
  end

  def update_quiet_hours_settings(settings)
    settings.each do |key, value|
      current_user.set_setting("quiet_hours_#{key}", value.to_s)
    end
  end

  # 通知送信判定メソッド
  def should_send_push_notification?(notification_type)
    return false unless current_user.get_setting("push_notifications_enabled", "true") == "true"
    return false if in_quiet_hours?

    case notification_type
    when "kpt_reminder"
      current_user.get_setting("push_kpt_reminders", "true") == "true"
    when "item_due"
      current_user.get_setting("push_item_due_alerts", "true") == "true"
    when "achievement"
      current_user.get_setting("push_achievement_alerts", "true") == "true"
    else
      true
    end
  end

  def should_send_email_notification?(notification_type)
    return false unless current_user.get_setting("email_notifications_enabled", "true") == "true"

    case notification_type
    when "kpt_session_completed"
      current_user.get_setting("email_kpt_session_completed", "true") == "true"
    when "weekly_summary"
      current_user.get_setting("email_weekly_summary", "true") == "true"
    when "item_reminder"
      current_user.get_setting("email_item_reminders", "true") == "true"
    when "system"
      current_user.get_setting("email_system_updates", "false") == "true"
    else
      false
    end
  end

  # 通知停止時間内かどうか判定
  def in_quiet_hours?
    return false unless current_user.get_setting("quiet_hours_enabled", "false") == "true"

    start_time = current_user.get_setting("quiet_hours_start", "22:00")
    end_time = current_user.get_setting("quiet_hours_end", "08:00")
    user_timezone = current_user.timezone || "Asia/Tokyo"

    current_time = Time.current.in_time_zone(user_timezone).strftime("%H:%M")

    if start_time < end_time
      current_time >= start_time && current_time <= end_time
    else
      current_time >= start_time || current_time <= end_time
    end
  end

  # 実際の通知送信メソッド（仮実装）
  def send_push_notification(notification)
    # 実際の実装では、WebPush、FCM、APNsなどを使用
  end

  def send_email_notification(notification)
    # 実際の実装では、ActionMailerを使用
  end

  # 統計計算メソッド
  def calculate_read_rate(notifications)
    return 0.0 if notifications.count.zero?
    (notifications.where(is_read: true).count.to_f / notifications.count * 100).round(2)
  end

  def calculate_average_response_time(notifications)
    read_notifications = notifications.where(is_read: true).where.not(read_at: nil)
    return 0 if read_notifications.count.zero?

    total_seconds = read_notifications.sum do |n|
      (n.read_at - n.created_at).to_i
    end

    (total_seconds / read_notifications.count / 3600.0).round(2) # 時間単位
  end

  def generate_daily_notification_trends(notifications, start_date)
    (start_date.to_date..Date.current).map do |date|
      day_notifications = notifications.where(created_at: date.beginning_of_day..date.end_of_day)

      {
        date: date,
        total: day_notifications.count,
        unread: day_notifications.unread.count,
        by_type: day_notifications.group(:notification_type).count
      }
    end
  end

  # 表示用ヘルパーメソッド
  def notification_type_ja(type)
    case type
    when "kpt_reminder"
      "KPTリマインダー"
    when "item_due"
      "アイテム期限"
    when "kpt_session_completed"
      "KPTセッション完了"
    when "weekly_summary"
      "週次サマリー"
    when "achievement"
      "実績解除"
    when "system"
      "システム通知"
    else
      type
    end
  end

  def priority_name_ja(priority)
    case priority
    when "low"
      "低"
    when "normal"
      "通常"
    when "high"
      "高"
    when "urgent"
      "緊急"
    else
      priority
    end
  end

  def time_ago_in_words(time)
    diff = Time.current - time

    case diff
    when 0..59
      "#{diff.to_i}秒前"
    when 60..3599
      "#{(diff / 60).to_i}分前"
    when 3600..86399
      "#{(diff / 3600).to_i}時間前"
    else
      "#{(diff / 86400).to_i}日前"
    end
  end
end
