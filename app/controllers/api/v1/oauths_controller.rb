# frozen_string_literal: true

class Api::V1::OauthsController < ApplicationController
  include Sorcery::Controller

  def oauth
    login_at(auth_params[:provider])
  end

  def callback
    provider = auth_params[:provider]

    if (user = login_from(provider))
      redirect_to_login_with_params(user)
    else
      begin
        user = create_or_find_user_from_provider(provider)
        redirect_to_login_with_params(user)
      rescue => e
        render json: { error: "Failed to login from #{provider.titleize}: #{e.message}" }, status: :unprocessable_entity
      end
    end
  end

  private

  def auth_params
    params.permit(:code, :provider, :scope, :authuser, :prompt)
  end

  def redirect_to_login_with_params(user)
    # user_id, uid, provider, exp（有効期限）をjwtにセット
    payload = { 
      user_id: user.id, 
      uid: user.uid, 
      provider: user.provider,
      exp: 24.hours.from_now.to_i 
    }.to_json

    cookies.encrypted[:jwt] = {
      value: payload,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      domain: Rails.env.production? ? ".kpt-connect.biz": nil,
      path: "/",
      expires: 24.hours.from_now
    }

    redirect_to ENV["FRONTEND_URL"], allow_other_host: true
  end

  def create_or_find_user_from_provider(provider)
    user_info = @user_hash[:user_info]
    uid = user_info["id"].to_s # すべてのプロバイダーで共通
    email = user_info["email"]
    username = user_info["login"] || user_info["name"] || email.split("@").first

    # まず、同じproviderとuidでユーザーを検索
    user = User.find_by(provider: provider, uid: uid)
    
    if user
      # 既存ユーザーが見つかった場合、情報を更新
      if !user.is_active?
        user.is_active = true
        user.deleted_at = nil if user.respond_to?(:deleted_at)
      end
      user.email = email
      user.username = username
      user.save!
    else
      # 同じproviderとuidのユーザーが見つからない場合、emailで検索
      existing_user = User.find_by(email: email)
      
      if existing_user
        # 同じemailのユーザーが存在する場合、そのユーザーを更新
        existing_user.provider = provider
        existing_user.uid = uid
        existing_user.username = username
        existing_user.is_active = true
        existing_user.deleted_at = nil if existing_user.respond_to?(:deleted_at)
        existing_user.save!
        user = existing_user
      else
        # 新しいユーザーを作成
        user = User.create!(
          provider: provider,
          uid: uid,
          email: email,
          username: username,
          language: "ja",
          timezone: nil,
          is_active: true
        )
      end
    end
    user
  end
end
