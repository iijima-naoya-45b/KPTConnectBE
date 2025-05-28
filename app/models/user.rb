# frozen_string_literal: true

##
# ユーザーモデル
# OAuth認証によるユーザー情報を管理するActiveRecordモデル
# 
# Google OAuth認証を通じてユーザーを管理し、
# 複数の認証プロバイダーに対応可能な設計
#
# @attr [String] email ユーザーのメールアドレス（必須、一意）
# @attr [String] username ユーザー名
# @attr [String] provider 認証プロバイダー（google等、必須）
# @attr [String] uid プロバイダー固有のユーザーID（必須、プロバイダー内で一意）
#
class User < ApplicationRecord
  authenticates_with_sorcery!

  validates :email, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  has_many :authentications, dependent: :destroy
end
