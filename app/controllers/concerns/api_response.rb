# frozen_string_literal: true

module ApiResponse
  extend ActiveSupport::Concern

  # 成功レスポンス
  def render_success(data: nil, message: nil, status: :ok)
    response = { success: true }
    response[:data] = data if data.present?
    response[:message] = message if message.present?
    
    render json: response, status: status
  end

  # エラーレスポンス
  def render_error(error:, status: :internal_server_error, details: nil)
    response = {
      success: false,
      error: error
    }
    response[:details] = details if details.present?
    
    render json: response, status: status
  end

  # バリデーションエラーレスポンス
  def render_validation_error(record, message: "バリデーションエラーが発生しました")
    render json: {
      success: false,
      error: message,
      details: record.errors.full_messages
    }, status: :unprocessable_entity
  end

  # リソースが見つからないエラーレスポンス
  def render_not_found(message: "リソースが見つかりません")
    render json: {
      success: false,
      error: message
    }, status: :not_found
  end

  # 認証エラーレスポンス
  def render_unauthorized(message: "認証が必要です")
    render json: {
      success: false,
      error: message
    }, status: :unauthorized
  end

  # 権限エラーレスポンス
  def render_forbidden(message: "アクセス権限がありません")
    render json: {
      success: false,
      error: message
    }, status: :forbidden
  end
end 