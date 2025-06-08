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
    # user_id, uid, providerをjwtにセット
    payload = { user_id: user.id, uid: user.uid, provider: user.provider }.to_json

    Rails.logger.info "Setting cookie for user: #{user.id}, uid: #{user.uid}, provider: #{user.provider}, payload: #{payload}"

    cookies.encrypted[:jwt] = {
      value: payload,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      domain: Rails.env.development? ? "localhost" : nil,
      path: "/",
      expires: 1.hour.from_now
    }

    redirect_to ENV["FRONTEND_URL"]
  end

  def create_or_find_user_from_provider(provider)
    user_info = @user_hash[:user_info]
    uid = user_info["id"].to_s # すべてのプロバイダーで共通
    email = user_info["email"]
    username = user_info["login"] || user_info["name"]
    name = user_info["name"] || user_info["login"]

    Rails.logger.info "OAuth Provider: #{provider}"
    Rails.logger.info "User Hash: #{@user_hash}"
    Rails.logger.info "Processed - Email: #{email}, Username: #{username}, Name: #{name}, UID: #{uid}"

    user = User.find_by(provider: provider, uid: uid)
    if user
      if !user.is_active?
        user.is_active = true
        user.deleted_at = nil if user.respond_to?(:deleted_at)
        user.email = email
        user.username = username
        user.name = name
        user.save!
        Rails.logger.info "User reactivated and info updated: #{user.id}"
      end
    else
      user = User.create!(
        provider: provider,
        uid: uid,
        email: email,
        username: username,
        name: name,
        language: "ja",
        timezone: nil,
        is_active: true
      )
      Rails.logger.info "New user created: #{user.id}"
    end
    user
  end
end
