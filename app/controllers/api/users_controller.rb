require "net/http"
require "json"
require "jwt"

class Api::UsersController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # Google公開鍵を取得
    public_key = fetch_google_public_key

    begin
      # JWTトークンを検証
      decoded_token = JWT.decode(params[:id_token], public_key, true, { algorithm: "RS256" })

      # トークンが有効なら、emailやnameを取り出してDBに保存
      email = decoded_token[0]["email"]
      name = decoded_token[0]["name"]
      avatar_url = decoded_token[0]["picture"]

      # DBにユーザーを保存
      user = User.find_or_initialize_by(email: email)
      user.update!(name: name, avatar_url: avatar_url)

      render json: { status: "ok", user: user }

    rescue JWT::DecodeError => e
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  private

  def fetch_google_public_key
    uri = URI("https://www.googleapis.com/oauth2/v3/certs")
    response = Net::HTTP.get(uri)
    JSON.parse(response)["keys"].first # ここでは最初の鍵を使用（通常1つの公開鍵）
  end
end
