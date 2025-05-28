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
    # トークンではなく JSON 文字列を保存
    payload = { user_id: user.id }.to_json

    cookies.encrypted[:jwt] = {
      value: payload,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: 1.hour.from_now
    }

    redirect_to ENV["FRONTEND_URL"]
  end

  def create_or_find_user_from_provider(provider)
    uid = @user_hash[:uid]
    user_info = @user_hash[:user_info]

    User.find_or_create_by(provider: provider, uid: uid) do |user|
      user.email = user_info["email"]
      user.username = user_info["name"]
    end
  end
end
