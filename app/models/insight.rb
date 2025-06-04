# frozen_string_literal: true

# インサイトモデル
# 
# @description AI分析による振り返りサマリ・メタ情報を管理するモデル
# KPTセッションに対する分析結果やパターン、推奨事項を保存
# 
# @attr [UUID] kpt_session_id KPTセッションID
# @attr [Integer] user_id ユーザーID
# @attr [String] insight_type インサイトタイプ (summary, sentiment, trend, recommendation, pattern)
# @attr [String] title インサイトタイトル
# @attr [JSON] content インサイト内容（JSON形式）
# @attr [Decimal] confidence_score 信頼度スコア (0.0-1.0)
# @attr [String] data_source データソース
# @attr [JSON] metadata メタデータ
# @attr [Boolean] is_active アクティブフラグ
class Insight < ApplicationRecord
  # リレーション
  belongs_to :kpt_session
  belongs_to :user

  # バリデーション
  validates :insight_type, presence: true, 
            inclusion: { in: %w[summary sentiment trend recommendation pattern] }
  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  validates :confidence_score, presence: true, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :data_source, presence: true, length: { maximum: 50 }

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(insight_type: type) }
  scope :high_confidence, -> { where('confidence_score >= ?', 0.8) }
  scope :recent, -> { order(created_at: :desc) }

  # インスタンスメソッド

  # インサイトが高信頼度かチェック
  # @return [Boolean] 高信頼度フラグ
  def high_confidence?
    confidence_score >= 0.8
  end

  # インサイトをアクティブ化
  def activate!
    update!(is_active: true)
  end

  # インサイトを非アクティブ化
  def deactivate!
    update!(is_active: false)
  end

  # クラスメソッド

  # 特定のユーザーの最新インサイトを取得
  # @param [User] user ユーザー
  # @param [Integer] limit 取得件数
  # @return [Array<Insight>] インサイト一覧
  def self.latest_for_user(user, limit = 10)
    where(user: user).active.recent.limit(limit)
  end

  # 特定のKPTセッションのインサイトサマリーを取得
  # @param [KptSession] session KPTセッション
  # @return [Hash] インサイトサマリー
  def self.summary_for_session(session)
    insights = where(kpt_session: session).active

    {
      total_count: insights.count,
      by_type: insights.group(:insight_type).count,
      average_confidence: insights.average(:confidence_score)&.round(2),
      high_confidence_count: insights.high_confidence.count
    }
  end
end 