# frozen_string_literal: true

# フィードバック優先度モデル
#
# @description フィードバックの優先度を管理するマスターモデル
# フロントエンドの選択肢と連携してフィードバック優先度の一元管理を行う
#
# @attr [String] name フィードバック優先度名
# @attr [String] key フィードバック優先度キー（システム内部用）
# @attr [String] description フィードバック優先度説明
# @attr [Integer] display_order 表示順序
# @attr [Integer] priority_level 優先度レベル（数値が大きいほど高優先度）
# @attr [Boolean] is_active アクティブ状態
# @attr [String] color_code 表示用カラーコード
# @attr [String] badge_class CSSバッジクラス名
class FeedbackPriority < ApplicationRecord
  # リレーション
  has_many :feedbacks, dependent: :restrict_with_error

  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :key, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :priority_level, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :color_code, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "は#FFFFFFの形式で入力してください" }, allow_blank: true
  validates :badge_class, length: { maximum: 100 }, allow_blank: true

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :created_at) }
  scope :ordered_by_priority, -> { order(priority_level: :desc) }
  scope :for_select, -> { active.ordered.pluck(:name, :id) }

  # クラスメソッド

  # キーからフィードバック優先度を取得
  # @param [String] key フィードバック優先度キー
  # @return [FeedbackPriority, nil] フィードバック優先度オブジェクト
  def self.find_by_key(key)
    find_by(key: key, is_active: true)
  end

  # アクティブなフィードバック優先度のキー配列を取得
  # @return [Array<String>] キー配列
  def self.active_keys
    active.pluck(:key)
  end

  # 高優先度のフィードバック優先度を取得
  # @return [FeedbackPriority] 最高優先度オブジェクト
  def self.highest_priority
    active.ordered_by_priority.first
  end

  # フィードバック優先度の統計情報を取得
  # @return [Hash] 優先度ごとの統計データ
  def self.statistics
    active.includes(:feedbacks).map do |priority|
      feedbacks_count = priority.feedbacks.count
      unread_count = priority.feedbacks.where(status: "unread").count

      {
        id: priority.id,
        name: priority.name,
        key: priority.key,
        priority_level: priority.priority_level,
        total_feedbacks: feedbacks_count,
        unread_feedbacks: unread_count,
        color_code: priority.color_code,
        badge_class: priority.badge_class
      }
    end
  end

  # インスタンスメソッド

  # フィードバック優先度の表示名を取得
  # @return [String] 表示名
  def display_name
    name
  end

  # アクティブかどうかをチェック
  # @return [Boolean] アクティブ状態
  def is_active?
    is_active
  end

  # 高優先度かどうかをチェック
  # @return [Boolean] 高優先度判定
  def high_priority?
    priority_level >= 3
  end

  # 中優先度かどうかをチェック
  # @return [Boolean] 中優先度判定
  def medium_priority?
    priority_level == 2
  end

  # 低優先度かどうかをチェック
  # @return [Boolean] 低優先度判定
  def low_priority?
    priority_level == 1
  end

  # この優先度のフィードバック数を取得
  # @return [Integer] フィードバック数
  def feedbacks_count
    feedbacks.count
  end

  # この優先度の未読フィードバック数を取得
  # @return [Integer] 未読フィードバック数
  def unread_feedbacks_count
    feedbacks.where(status: "unread").count
  end

  # この優先度の最新フィードバックを取得
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] フィードバック配列
  def recent_feedbacks(limit = 5)
    feedbacks.includes(:user, :feedback_type)
             .order(created_at: :desc)
             .limit(limit)
  end
end
