# frozen_string_literal: true

# 通知モデル
class Notification < ApplicationRecord
  belongs_to :user

  # スコープ
  scope :unread, -> { where(is_read: false) }

  # バリデーション
  validates :title, presence: true
  validates :message, presence: true
  validates :notification_type, presence: true
end
