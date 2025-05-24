# app/controllers/api/v1/sessions_controller.rb
class Api::V1::SessionsController < ApplicationController
  include JsonWebToken

      skip_before_action :require_login, only: [ :create ]

      def create
        user = login(params[:email], params[:password])
        if user
          token = JsonWebToken.encode(user_id: user.id)
      
          cookies.encrypted[:jwt] = {
            value: token,
            httponly: true,
            secure: Rails.env.production?,
            same_site: :lax,
            expires: 1.hour.from_now
          }
      
          render json: { message: "Login successful" }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end
end
