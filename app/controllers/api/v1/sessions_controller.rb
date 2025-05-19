# app/controllers/api/v1/sessions_controller.rb
module Api
  module V1
    class SessionsController < ApplicationController
      include JsonWebToken

      skip_before_action :require_login, only: [ :create ]

      def create
        user = login(params[:email], params[:password])
        if user
          token = JsonWebToken.encode(user_id: user.id)
          render json: { token: token }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end
    end
  end
end
