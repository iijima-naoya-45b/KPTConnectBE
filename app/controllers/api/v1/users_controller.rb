# frozen_string_literal: true

class Api::V1::UsersController < ApplicationController
  include JsonWebToken

  before_action :require_login

  def me
    if current_user
      render json: {
        id: current_user.id.to_s,
        email: current_user.email,
        username: current_user.username,
        provider: current_user.provider
      }, status: :ok
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
  
end 