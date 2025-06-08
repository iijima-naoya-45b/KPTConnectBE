# frozen_string_literal: true

# 認証APIコントローラー
class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!, only: [:logout]

  # ログイン
  def login
    # ... 既存の処理 ...
  end

  # ... その他のアクション ...
end 