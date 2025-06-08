# frozen_string_literal: true

# テンプレートAPIコントローラー
class Api::V1::TemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: [ :show, :update, :destroy, :copy, :share, :unshare ]

  # テンプレート一覧を取得
  def index
    # ... 既存の処理 ...
  end

  # ... その他のアクション ...
end
