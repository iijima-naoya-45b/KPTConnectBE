class Api::V1::OauthsController < ApplicationController
  include JsonWebToken
  include Sorcery::Controller

  def oauth
    login_at(auth_params[:provider])
  end

  def callback
    provider = auth_params[:provider]
    if (user = login_from(provider))
      redirect_to_login_with_params(user, provider)
    else
      begin
        user = create_or_find_user_from_provider(provider)
        redirect_to_login_with_params(user, provider)
      rescue => e
        render json: { error: "Failed to login from #{provider.titleize}: #{e.message}" }, status: :unprocessable_entity
      end
    end
  end

  private

  def auth_params
    params.permit(:code, :provider, :scope, :authuser, :prompt)
  end

  def redirect_to_login_with_params(user, provider)

    token = JsonWebToken.encode(user_id: user.id)

    # Redisに保存（有効期限1時間）
    $redis.set("jwt:#{user.id}", token, ex: 3600)

    # JWTはURLに含めずuser_idだけ渡す
    redirect_to "http://localhost:3000/oauth/callback?user_id=#{user.id}"
  end

  def create_or_find_user_from_provider(provider)
    Rails.logger.info("User hash in create_or_find_user_from_provider: #{@user_hash.inspect}")

    return nil if @user_hash.nil?

    uid = @user_hash[:uid]
    user_info = @user_hash[:user_info]

    User.find_or_create_by(provider: provider, uid: uid) do |user|
      user.email = user_info["email"]
      user.username = user_info["name"]
      # 必要なら他の属性もここでセット
    end
  end
end
