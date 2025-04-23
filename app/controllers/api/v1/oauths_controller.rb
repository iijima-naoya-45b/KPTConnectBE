class Api::V1::OauthsController < ApplicationController
  skip_before_action :require_login, only: [ :oauth, :callback ]

  def oauth
    login_at(auth_params[:provider])
  end

  def callback
    provider = auth_params[:provider]
    if @user = login_from(provider)
      render json: { message: "Logged in from #{provider.titleize}!" }, status: :ok
    else
      begin
        @user = create_or_find_user_from_provider(provider)
        reset_session # protect from session fixation attack
        auto_login(@user)
        render json: { message: "Logged in from #{provider.titleize}!" }, status: :ok
      rescue => e
        render json: { error: "Failed to login from #{provider.titleize}: #{e.message}" }, status: :unprocessable_entity
      end
    end
  end

  private

  def auth_params
    params.permit(:code, :provider)
  end

  def create_or_find_user_from_provider(provider)
    user_info = sorcery_fetch_user_hash(provider)
    User.create_or_find_by(provider: provider, uid: user_info[:uid]) do |user|
      user.email = user_info[:user_info]["email"]
      user.username = user_info[:user_info]["name"]
    end
  end
end
