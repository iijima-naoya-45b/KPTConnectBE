# frozen_string_literal: true

# 認証APIコントローラー
class Api::V1::AuthController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!, only: [:logout]

  # ログイン
  def login
    # ... 既存の処理 ...
  end

  # ... その他のアクション ...
end 