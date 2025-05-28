# frozen_string_literal: true

##
# 認証情報モデル
# ユーザーとOAuth認証プロバイダーとの関連を管理
# 
# 一人のユーザーが複数の認証プロバイダー（Google、Facebook等）を
# 使用できるようにするための中間テーブル
#
# @attr [Integer] user_id ユーザーID（外部キー）
# @attr [String] provider 認証プロバイダー名
# @attr [String] uid プロバイダー固有のユーザーID
#
class Authentication < ApplicationRecord
  belongs_to :user
end
