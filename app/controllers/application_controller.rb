# frozen_string_literal: true

# アプリケーションベースコントローラー
#
# @description 全APIコントローラーの基底クラス
# 認証、エラーハンドリング、共通機能を提供
#
# @methods
# - authenticate_user! ユーザー認証必須
# - current_user 現在のユーザーを取得
# - require_login ログイン必須チェック（既存互換性のため）
class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :set_current_user_from_cookie

  # カスタム例外クラス
  class AuthenticationError < StandardError; end
  class AuthorizationError < StandardError; end

  # 例外ハンドリング
  rescue_from AuthenticationError, with: :handle_authentication_error
  rescue_from AuthorizationError, with: :handle_authorization_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  private

  # Cookieからユーザー情報を設定
  def set_current_user_from_cookie
    jwt = cookies.encrypted[:jwt]
    return unless jwt

    begin
      payload = JSON.parse(jwt)
      user_id = payload["user_id"]
      
      if user_id.present?
        @current_user = User.active.find_by(id: user_id)
      end
    rescue JSON::ParserError, StandardError => e
      @current_user = nil
      # Cookieをクリア
      cookies.delete(:jwt)
    end
  end

  # 現在のユーザーを取得
  # @return [User, nil] 現在のユーザー
  def current_user
    @current_user
  end

  # ユーザー認証が必須
  # @raise [AuthenticationError] 認証されていない場合
  def authenticate_user!
    unless current_user
      raise AuthenticationError, 'ログインが必要です'
    end

    unless current_user.is_active?
      raise AuthenticationError, 'アカウントが無効です'
    end

    # 最終ログイン時刻を更新
    update_last_login_at
  end

  # ログイン必須チェック（既存互換性のため）
  def require_login
    authenticate_user!
  rescue AuthenticationError
    render json: { 
      success: false,
      error: 'Unauthorized',
      message: 'ログインが必要です'
    }, status: :unauthorized
  end

  # プロプラン権限をチェック
  def require_pro_plan!
    authenticate_user!
    
    unless current_user.pro_plan?
      raise AuthorizationError, 'プロプランの契約が必要です'
    end
  end

  # 管理者権限をチェック
  def require_admin!
    authenticate_user!
    
    unless current_user.admin?
      raise AuthorizationError, '管理者権限が必要です'
    end
  end

  # レスポンス成功時の共通フォーマット
  # @param [Hash] data レスポンスデータ
  # @param [String] message メッセージ
  # @param [Symbol] status HTTPステータス
  def render_success(data: nil, message: '正常に処理されました', status: :ok)
    response_data = {
      success: true,
      message: message
    }
    response_data[:data] = data if data.present?

    render json: response_data, status: status
  end

  # レスポンス失敗時の共通フォーマット
  # @param [String] error エラーメッセージ
  # @param [Array, String] details 詳細エラー
  # @param [Symbol] status HTTPステータス
  def render_error(error: 'エラーが発生しました', details: nil, status: :internal_server_error)
    response_data = {
      success: false,
      error: error
    }
    response_data[:details] = details if details.present?

    render json: response_data, status: status
  end

  # 最終ログイン時刻を更新
  def update_last_login_at
    return unless current_user

    # 1時間以内の更新は避ける（パフォーマンス考慮）
    last_updated = current_user.last_login_at
    if last_updated.nil? || last_updated < 1.hour.ago
      current_user.update_column(:last_login_at, Time.current)
    end
  end

  # 例外ハンドラー

  # 認証エラーハンドリング
  def handle_authentication_error(exception)
    render json: {
      success: false,
      error: 'Unauthorized',
      message: exception.message
    }, status: :unauthorized
  end

  # 認可エラーハンドリング
  def handle_authorization_error(exception)
    render json: {
      success: false,
      error: 'Forbidden',
      message: exception.message
    }, status: :forbidden
  end

  # リソース未発見エラーハンドリング
  def handle_not_found(exception)
    render json: {
      success: false,
      error: 'Not Found',
      message: 'リソースが見つかりません'
    }, status: :not_found
  end

  # パラメーター不足エラーハンドリング
  def handle_parameter_missing(exception)
    render json: {
      success: false,
      error: 'Bad Request',
      message: '必須パラメーターが不足しています',
      details: exception.message
    }, status: :bad_request
  end
end
