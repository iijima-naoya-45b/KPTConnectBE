# frozen_string_literal: true

##
# JSON Web Token管理モジュール
# JWTトークンのエンコード・デコード機能を提供
# Railsのsecret_key_baseを使用したセキュアなトークン管理
#
module JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base

  ##
  # JWTトークンをエンコード
  # ユーザーIDと有効期限を含むJWTトークンを生成
  #
  # @param [Hash] payload エンコードするデータ
  # @param [Time] exp 有効期限（デフォルト: 24時間後）
  # @return [String] エンコードされたJWTトークン
  #
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  ##
  # JWTトークンをデコード
  # 暗号化されたトークンを復号化してペイロードを取得
  #
  # @param [String] token デコードするJWTトークン
  # @return [HashWithIndifferentAccess, nil] デコードされたデータ、無効な場合はnil
  #
  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  rescue
    nil
  end
end
