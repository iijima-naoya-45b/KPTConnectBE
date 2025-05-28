# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :set_current_user_from_cookie

  private

  def set_current_user_from_cookie
    jwt = cookies.encrypted[:jwt]
    Rails.logger.debug "Encrypted cookie JWT: #{jwt.inspect}"
    return unless jwt

    begin
      payload = JSON.parse(jwt)
      @current_user = User.find_by(id: payload["user_id"])
    rescue => e
      @current_user = nil
    end
  end

  def current_user
    @current_user
  end

  def require_login
    render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
  end
end
