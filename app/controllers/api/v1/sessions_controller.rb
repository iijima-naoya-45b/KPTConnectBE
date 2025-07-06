# frozen_string_literal: true

class Api::V1::SessionsController < ApplicationController
  def create
    user = login(params[:email], params[:password])

    if user
      payload = { user_id: user.id }.to_json

      cookies.encrypted[:jwt] = {
        value: payload,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        domain: Rails.env.production? ? ".kpt-connect.biz": nil,
        expires: 1.hour.from_now
      }

      render json: { message: "Login successful" }, status: :ok
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def logout
    cookies.delete(:jwt)
    render json: { message: "Logout successful" }, status: :ok
  end
end
