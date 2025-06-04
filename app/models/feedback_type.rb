# frozen_string_literal: true

# フィードバック種別モデル
#
# @description フィードバックの種別を管理するマスターモデル
# フロントエンドの選択肢と連携してフィードバック種別の一元管理を行う
#
# @attr [String] name フィードバック種別名
# @attr [String] key フィードバック種別キー（システム内部用）
# @attr [String] description フィードバック種別説明
# @attr [Integer] display_order 表示順序
# @attr [Boolean] is_active アクティブ状態
# @attr [String] color_code 表示用カラーコード
# @attr [String] icon_name アイコン名
class FeedbackType < ApplicationRecord
  # リレーション
  has_many :feedbacks, dependent: :restrict_with_error

  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :key, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :color_code, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: 'は#FFFFFFの形式で入力してください' }, allow_blank: true
  validates :icon_name, length: { maximum: 50 }, allow_blank: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :created_at) }
  scope :for_select, -> { active.ordered.pluck(:name, :id) }

  # クラスメソッド

  # キーからフィードバック種別を取得
  # @param [String] key フィードバック種別キー
  # @return [FeedbackType, nil] フィードバック種別オブジェクト
  def self.find_by_key(key)
    find_by(key: key, is_active: true)
  end

  # アクティブなフィードバック種別のキー配列を取得
  # @return [Array<String>] キー配列
  def self.active_keys
    active.pluck(:key)
  end

  # フィードバック種別の統計情報を取得
  # @return [Hash] 種別ごとの統計データ
  def self.statistics
    active.includes(:feedbacks).map do |type|
      feedbacks_count = type.feedbacks.count
      recent_count = type.feedbacks.where('created_at >= ?', 1.month.ago).count
      
      {
        id: type.id,
        name: type.name,
        key: type.key,
        total_feedbacks: feedbacks_count,
        recent_feedbacks: recent_count,
        color_code: type.color_code,
        icon_name: type.icon_name
      }
    end
  end

  # インスタンスメソッド

  # フィードバック種別の表示名を取得
  # @return [String] 表示名
  def display_name
    name
  end

  # アクティブかどうかをチェック
  # @return [Boolean] アクティブ状態
  def is_active?
    is_active
  end

  # この種別のフィードバック数を取得
  # @return [Integer] フィードバック数
  def feedbacks_count
    feedbacks.count
  end

  # この種別の未読フィードバック数を取得
  # @return [Integer] 未読フィードバック数
  def unread_feedbacks_count
    feedbacks.where(status: 'unread').count
  end

  # この種別の最新フィードバックを取得
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] フィードバック配列
  def recent_feedbacks(limit = 5)
    feedbacks.includes(:user, :feedback_priority)
             .order(created_at: :desc)
             .limit(limit)
  end
end 