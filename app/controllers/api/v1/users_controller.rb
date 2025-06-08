# frozen_string_literal: true

# ユーザーAPIコントローラー
class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!

  # 現在のユーザー情報を取得
  # @route GET /api/v1/me
  # @response [JSON] ユーザー情報
  def me

    if current_user
      render json: {
        id: current_user.id.to_s,
        email: current_user.email,
        username: current_user.username,
        provider: current_user.provider
      }, status: :ok
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  # ユーザー情報を更新
  # @route PUT /api/v1/me
  # @param [Hash] user ユーザー情報
  # @response [JSON] 更新されたユーザー情報
  def update
    begin
      if current_user.update(user_params)
        user_data = format_user_detail(current_user)

        render json: {
          success: true,
          data: user_data,
          message: "ユーザー情報を更新しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "ユーザー情報の更新に失敗しました",
          details: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "ユーザー情報の更新中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # ユーザー設定を取得
  # @route GET /api/v1/users/settings
  # @response [JSON] ユーザー設定
  def settings
    begin
      settings_data = {
        user_settings: format_user_settings(current_user),
        default_settings: get_default_settings,
        available_options: get_available_options
      }

      render json: {
        success: true,
        data: settings_data,
        message: "ユーザー設定を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "ユーザー設定の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # ユーザー設定を更新
  # @route PUT /api/v1/users/settings
  # @param [Hash] settings 設定データ
  # @response [JSON] 更新された設定
  def update_settings
    begin
      updated_settings = {}
      errors = []

      # 各設定を個別に更新
      settings_params.each do |key, value|
        begin
          current_user.set_setting(key, value.to_s)
          updated_settings[key] = value
        rescue StandardError => e
          errors << "#{key}: #{e.message}"
        end
      end

      if errors.empty?
        render json: {
          success: true,
          data: {
            updated_settings: updated_settings,
            all_settings: format_user_settings(current_user)
          },
          message: "ユーザー設定を更新しました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "一部の設定の更新に失敗しました",
          details: errors
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "ユーザー設定の更新中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # ユーザー統計を取得
  # @route GET /api/v1/users/stats
  # @response [JSON] ユーザー統計
  def stats
    begin
      stats_data = {
        account_info: {
          member_since: current_user.created_at,
          last_login: current_user.last_login_at,
          total_logins: calculate_total_logins,
          account_status: current_user.is_active? ? "active" : "inactive"
        },
        kpt_stats: current_user.kpt_overview_stats,
        subscription_info: format_subscription_info(current_user),
        storage_usage: calculate_storage_usage
      }

      render json: {
        success: true,
        data: stats_data,
        message: "ユーザー統計を取得しました"
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: "ユーザー統計の取得に失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アカウントを削除
  # @route DELETE /api/v1/users/account
  # @param [String] confirmation 削除確認文字列
  # @response [JSON] 削除結果
  def destroy_account
    begin
      confirmation = params[:confirmation]

      if confirmation != current_user.email
        render json: {
          success: false,
          error: "アカウント削除の確認が正しくありません"
        }, status: :unprocessable_entity
        return
      end

      # タイムスタンプベースの一意なメールアドレスを生成
      timestamp = Time.current.to_i
      unique_email = "deleted_#{current_user.id}_#{timestamp}@deleted.com"

      # メールアドレスの重複チェックと再生成
      counter = 0
      while User.exists?(email: unique_email) && counter < 100
        counter += 1
        unique_email = "deleted_#{current_user.id}_#{timestamp}_#{counter}@deleted.com"
      end

      # アカウント削除処理（論理削除）
      ActiveRecord::Base.transaction do
        # KPTセッションをアーカイブ状態に変更
        sessions_updated = current_user.kpt_sessions.update_all(status: "archived", updated_at: Time.current)
        # ユーザーアカウントの論理削除
        update_params = {
          is_active: false,
          email: unique_email,
          username: "deleted_#{current_user.id}_#{timestamp}",
          name: "削除済みユーザー",
          avatar_url: nil,
          deleted_at: Time.current,
          timezone: current_user.timezone,  # 既存の値を保持
          language: current_user.language   # 既存の値を保持
        }

        unless current_user.update(update_params)
          render json: {
            success: false,
            error: "アカウントの削除に失敗しました",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
          return
        end

      end

      # セッションをクリア
      cookies.delete(:jwt)

      render json: {
        success: true,
        message: "アカウントを削除しました"
      }, status: :ok

    rescue ActiveRecord::RecordInvalid => e
      render json: {
        success: false,
        error: "アカウントの削除に失敗しました",
        details: e.record.errors.full_messages
      }, status: :unprocessable_entity
    rescue StandardError => e

      render json: {
        success: false,
        error: "アカウント削除中にエラーが発生しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  # アバター画像をアップロード
  # @route POST /api/v1/users/avatar
  # @param [File] avatar アバター画像
  # @response [JSON] アップロード結果
  def upload_avatar
    begin
      # 実際の実装では、S3やCloudinaryなどのクラウドストレージを使用
      avatar_url = upload_to_storage(params[:avatar])

      if current_user.update(avatar_url: avatar_url)
        render json: {
          success: true,
          data: {
            avatar_url: avatar_url,
            user: format_user_detail(current_user)
          },
          message: "アバター画像をアップロードしました"
        }, status: :ok
      else
        render json: {
          success: false,
          error: "アバター画像の保存に失敗しました",
          details: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: {
        success: false,
        error: "アバター画像のアップロードに失敗しました",
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  # ユーザーパラメーターを許可
  def user_params
    params.require(:user).permit(:name, :username, :timezone, :language, :avatar_url)
  end

  # 設定パラメーターを許可
  def settings_params
    params.require(:settings).permit(
      :theme, :notifications_enabled, :email_notifications, :weekly_summary,
      :dashboard_layout, :default_session_template, :auto_save_interval,
      :date_format, :time_format, :first_day_of_week
    )
  end

  # ユーザー詳細を整形
  # @param [User] user ユーザー
  # @return [Hash] 整形されたユーザーデータ
  def format_user_detail(user)
    {
      id: user.id,
      email: user.email,
      username: user.username,
      name: user.name,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      provider: user.provider,
      timezone: user.timezone,
      language: user.language,
      is_active: user.is_active,
      admin: user.admin?,
      pro_plan: user.pro_plan?,
      email_verified_at: user.email_verified_at,
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  # ユーザー設定を整形
  # @param [User] user ユーザー
  # @return [Hash] 設定データ
  def format_user_settings(user)
    {
      theme: user.get_setting("theme", "light"),
      notifications_enabled: user.get_setting("notifications_enabled", "true") == "true",
      email_notifications: user.get_setting("email_notifications", "true") == "true",
      weekly_summary: user.get_setting("weekly_summary", "true") == "true",
      dashboard_layout: user.get_setting("dashboard_layout", "grid"),
      default_session_template: user.get_setting("default_session_template", "basic"),
      auto_save_interval: user.get_setting("auto_save_interval", "30").to_i,
      date_format: user.get_setting("date_format", "YYYY-MM-DD"),
      time_format: user.get_setting("time_format", "24"),
      first_day_of_week: user.get_setting("first_day_of_week", "1").to_i
    }
  end

  # デフォルト設定を取得
  # @return [Hash] デフォルト設定
  def get_default_settings
    {
      theme: "light",
      notifications_enabled: true,
      email_notifications: true,
      weekly_summary: true,
      dashboard_layout: "grid",
      default_session_template: "basic",
      auto_save_interval: 30,
      date_format: "YYYY-MM-DD",
      time_format: "24",
      first_day_of_week: 1
    }
  end

  # 利用可能なオプションを取得
  # @return [Hash] 利用可能なオプション
  def get_available_options
    {
      themes: [ "light", "dark", "auto" ],
      dashboard_layouts: [ "grid", "list", "compact" ],
      session_templates: [ "basic", "detailed", "agile", "personal" ],
      auto_save_intervals: [ 15, 30, 60, 120 ],
      date_formats: [ "YYYY-MM-DD", "DD/MM/YYYY", "MM/DD/YYYY", "DD-MM-YYYY" ],
      time_formats: [ "12", "24" ],
      first_day_of_week_options: [
        { value: 0, label: "日曜日" },
        { value: 1, label: "月曜日" },
        { value: 6, label: "土曜日" }
      ]
    }
  end

  # サブスクリプション情報を整形
  # @param [User] user ユーザー
  # @return [Hash] サブスクリプション情報
  def format_subscription_info(user)
    subscription = user.current_subscription

    if subscription
      {
        plan_name: subscription.plan_name,
        status: subscription.status,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        billing_cycle: subscription.billing_cycle,
        cancel_at_period_end: subscription.cancel_at_period_end
      }
    else
      {
        plan_name: "Free",
        status: "active",
        features: [ "基本KPT機能", "月5セッションまで", "コミュニティサポート" ]
      }
    end
  end

  # 総ログイン回数を計算（簡易版）
  # @return [Integer] ログイン回数
  def calculate_total_logins
    # 実際の実装では、ログイン履歴テーブルから取得
    current_user.last_login_at ? 50 : 1 # 仮の値
  end

  # ストレージ使用量を計算
  # @return [Hash] ストレージ使用量
  def calculate_storage_usage
    sessions_count = current_user.kpt_sessions.count
    items_count = current_user.kpt_items.count

    # 簡易計算（実際はファイルサイズなどを考慮）
    estimated_size_mb = (sessions_count * 0.1) + (items_count * 0.05)

    {
      used_mb: estimated_size_mb.round(2),
      total_mb: current_user.pro_plan? ? 1000 : 100,
      usage_percentage: [ (estimated_size_mb / (current_user.pro_plan? ? 1000 : 100) * 100), 100 ].min.round(2)
    }
  end

  # ファイルをストレージにアップロード（仮実装）
  # @param [File] file ファイル
  # @return [String] アップロードされたファイルのURL
  def upload_to_storage(file)
    # 実際の実装では、AWS S3、Cloudinary、Google Cloud Storageなどを使用
    # ここは仮の実装
    if file.present?
      "https://example.com/avatars/#{current_user.id}/#{SecureRandom.hex}.jpg"
    else
      raise StandardError, "ファイルが指定されていません"
    end
  end
end
