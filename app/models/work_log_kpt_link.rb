# frozen_string_literal: true

# 作業ログ-KPT関連付けモデル
#
# @description 作業ログとKPTセッションの多対多関係を管理するモデル
# 作業ログとKPTセッションの関連性とその質を記録
#
# @attr [UUID] work_log_id 作業ログID
# @attr [UUID] kpt_session_id KPTセッションID
# @attr [Integer] relevance_score 関連性スコア (1-5)
# @attr [Text] notes 関連付けの理由・メモ
class WorkLogKptLink < ApplicationRecord
  # リレーション
  belongs_to :work_log
  belongs_to :kpt_session

  # バリデーション
  validates :relevance_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :notes, length: { maximum: 1000 }

  # 複合ユニーク制約をモデルレベルでも検証
  validates :work_log_id, uniqueness: { scope: :kpt_session_id }

  # スコープ
  scope :high_relevance, -> { where("relevance_score >= ?", 4) }
  scope :by_relevance, ->(score) { where(relevance_score: score) }
  scope :recent, -> { order(created_at: :desc) }

  # インスタンスメソッド

  # 高関連性かチェック
  # @return [Boolean] 高関連性フラグ
  def high_relevance?
    relevance_score && relevance_score >= 4
  end

  # 関連性の説明テキストを取得
  # @return [String] 関連性説明
  def relevance_description
    case relevance_score
    when 5
      "非常に強い関連性"
    when 4
      "強い関連性"
    when 3
      "中程度の関連性"
    when 2
      "弱い関連性"
    when 1
      "非常に弱い関連性"
    else
      "未評価"
    end
  end

  # クラスメソッド

  # 特定のKPTセッションの関連作業ログ統計
  # @param [KptSession] session KPTセッション
  # @return [Hash] 統計データ
  def self.stats_for_session(session)
    links = where(kpt_session: session)

    {
      total_links: links.count,
      high_relevance_count: links.high_relevance.count,
      average_relevance: links.where.not(relevance_score: nil).average(:relevance_score)&.round(2),
      work_logs_count: links.joins(:work_log).count
    }
  end

  # 特定の作業ログの関連KPTセッション統計
  # @param [WorkLog] work_log 作業ログ
  # @return [Hash] 統計データ
  def self.stats_for_work_log(work_log)
    links = where(work_log: work_log)

    {
      total_links: links.count,
      high_relevance_count: links.high_relevance.count,
      average_relevance: links.where.not(relevance_score: nil).average(:relevance_score)&.round(2),
      kpt_sessions_count: links.joins(:kpt_session).count
    }
  end
end
