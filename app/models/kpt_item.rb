# frozen_string_literal: true

class KptItem < ApplicationRecord
  self.inheritance_column = nil


  belongs_to :kpt_session

  # バリデーション
  validates :type, inclusion: { in: %w[keep problem try] }
  validates :content, presence: true, length: { maximum: 2000 }
  validates :emotion_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :impact_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :assigned_to, length: { maximum: 100 }
  # スコープ
  scope :keeps, -> { where(type: "keep") }
  scope :problems, -> { where(type: "problem") }
  scope :tries, -> { where(type: "try") }
  scope :with_emotion_score, -> { where.not(emotion_score: nil) }
  scope :with_impact_score, -> { where.not(impact_score: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }

  # クラスメソッド

  # 感情スコアの傾向分析
  def self.emotion_trend(user, days = 30)
    start_date = days.days.ago
    items = joins(:kpt_session)
            .where(kpt_sessions: { user_id: user.id, session_date: start_date..Date.current })
            .with_emotion_score

    daily_average = items.group("DATE(kpt_sessions.session_date)")
                         .average(:emotion_score)

    daily_average.map { |date, avg| { date: date, average_score: avg.to_f.round(2) } }
                 .sort_by { |h| h[:date] }
  end

  # 影響度分布の分析
  def self.impact_distribution(user)
    items = joins(:kpt_session).where(kpt_sessions: { user_id: user.id })
    items.with_impact_score.group(:impact_score).count
  end

  # タイプ別統計
  def self.type_stats(user, start_date = 1.month.ago, end_date = Date.current)
    sessions = user.kpt_sessions.by_date_range(start_date, end_date)
    items = joins(:kpt_session).where(kpt_session: sessions)

    {
      keep: {
        total: items.keeps.count,
        avg_emotion_score: items.keeps.with_emotion_score.average(:emotion_score)&.round(2),
        avg_impact_score: items.keeps.with_impact_score.average(:impact_score)&.round(2)
      },
      problem: {
        total: items.problems.count,
        avg_emotion_score: items.problems.with_emotion_score.average(:emotion_score)&.round(2),
        avg_impact_score: items.problems.with_impact_score.average(:impact_score)&.round(2)
      },
      try: {
        total: items.tries.count,
        avg_emotion_score: items.tries.with_emotion_score.average(:emotion_score)&.round(2),
        avg_impact_score: items.tries.with_impact_score.average(:impact_score)&.round(2)
      }
    }
  end

  # 人気のタグを取得
  def self.popular_tags(user, type_filter = nil, limit = 10)
    items = joins(:kpt_session).where(kpt_sessions: { user_id: user.id })
    items = items.where(type: type_filter) if type_filter

    items.where.not(tags: [])
         .pluck(:tags)
         .flatten
         .tally
         .sort_by { |_, count| -count }
         .first(limit)
         .map { |tag, count| { tag: tag, count: count } }
  end

  # インスタンスメソッド

  # アイテムが完了しているかチェック
  # @return [Boolean] 完了状態
  def completed?
    status == "completed"
  end

  # アイテムがアクティブかチェック
  # @return [Boolean] アクティブ状態
  def active?
    ![ "completed", "cancelled" ].include?(status)
  end

  # 期限切れかチェック
  # @return [Boolean] 期限切れ状態
  def overdue?
    due_date.present? && due_date < Date.current && active?
  end

  # 期限が近いかチェック
  # @return [Boolean] 期限間近状態
  def due_soon?
    due_date.present? && due_date.between?(Date.current, 3.days.from_now) && active?
  end

  # アイテムタイプの日本語名を取得
  # @return [String] 日本語タイプ名
  def type_name_ja
    case type
    when "keep"
      "Keep (続けること)"
    when "problem"
      "Problem (問題)"
    when "try"
      "Try (試すこと)"
    end
  end

  # 優先度の日本語名を取得
  # @return [String] 日本語優先度名
  def priority_name_ja
    case priority
    when "low"
      "低"
    when "medium"
      "中"
    when "high"
      "高"
    end
  end

  # ステータスの表示名を取得
  # @return [String] ステータス表示名
  def status_display
    case status
    when "open"
      "オープン"
    when "in_progress"
      "進行中"
    when "completed"
      "完了"
    when "reopened"
      "再開"
    when "cancelled"
      "キャンセル"
    else
      status.to_s
    end
  end

  # アイテムの重要度スコアを計算
  # @return [Float] 重要度スコア (1.0-5.0)
  def importance_score
    emotion = emotion_score || 3.0
    impact = impact_score || 3.0
    priority_weight = case priority
    when "low" then 1.0
    when "medium" then 1.5
    when "high" then 2.0
    else 1.5
    end

    ((emotion + impact) / 2.0) * priority_weight
  end

  # 類似アイテムを検索
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] 類似アイテム
  def similar_items(limit = 5)
    return self.class.none if tags.empty?

    self.class.joins(:kpt_session)
        .where(kpt_sessions: { user_id: kpt_session.user_id })
        .where(type: type)
        .where.not(id: id)
        .where("tags && ARRAY[?]", tags)
        .limit(limit)
        .order(:created_at)
  end

  private


  # 完了日時を更新
  def update_completed_at
    if status == "completed" && completed_at.nil?
      update_column(:completed_at, Time.current)
    elsif status != "completed" && completed_at.present?
      update_column(:completed_at, nil)
    end
  end

  # 完了ステータスが変更されたかチェック
  def completed_status_changed?
    saved_change_to_status? && (status == "completed" || status_before_last_save == "completed")
  end

  # トレンド方向を計算
  def self.calculate_trend_direction(values)
    return "stable" if values.size < 2

    first_half = values.first(values.size / 2).sum / (values.size / 2)
    second_half = values.last(values.size / 2).sum / (values.size / 2)

    if second_half > first_half + 0.3
      "up"
    elsif second_half < first_half - 0.3
      "down"
    else
      "stable"
    end
  end
end
