# frozen_string_literal: true

# 振り返りマークモデル
#
# @description 個人振り返りカレンダーで特定の日付をマークするためのモデル
# ユーザーが振り返りを行った日や重要な日をマークして管理
#
# @attr [Integer] user_id ユーザーID
# @attr [Date] date マークした日付
# @attr [String] note メモ
# @attr [String] mark_type マークタイプ (reflection, milestone, goal, etc.)
# @attr [Hash] metadata 追加データ（JSON）
class ReflectionMark < ApplicationRecord
  # リレーション
  belongs_to :user

  # バリデーション
  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :mark_type, inclusion: { in: %w[reflection milestone goal achievement learning other] }
  validates :note, length: { maximum: 500 }

  # スコープ
  scope :recent, -> { order(date: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_type, ->(type) { where(mark_type: type) }
  scope :with_notes, -> { where.not(note: [ nil, "" ]) }

  # コールバック
  before_validation :set_default_mark_type, unless: :mark_type?

  # インスタンスメソッド

  # マークに関連するKPTセッションがあるかチェック
  # @return [Boolean] KPTセッションの存在
  def has_kpt_session?
    user.kpt_sessions.where(session_date: date).exists?
  end

  # その日のKPTセッションを取得
  # @return [ActiveRecord::Relation] KPTセッション
  def kpt_sessions
    user.kpt_sessions.where(session_date: date)
  end

  # マークの重要度を取得
  # @return [Integer] 重要度 (1-5)
  def importance_level
    case mark_type
    when "milestone", "achievement" then 5
    when "goal" then 4
    when "learning" then 3
    when "reflection" then 2
    else 1
    end
  end

  # 表示用のアイコンを取得
  # @return [String] アイコン名
  def icon
    case mark_type
    when "reflection" then "🤔"
    when "milestone" then "🎯"
    when "goal" then "📌"
    when "achievement" then "🏆"
    when "learning" then "📚"
    else "⭐"
    end
  end

  # 表示用の色を取得
  # @return [String] 色クラス
  def color_class
    case mark_type
    when "reflection" then "blue"
    when "milestone" then "purple"
    when "goal" then "indigo"
    when "achievement" then "yellow"
    when "learning" then "green"
    else "gray"
    end
  end

  # クラスメソッド

  # ユーザーの月別マーク統計を取得
  # @param [User] user ユーザー
  # @param [Integer] months 月数
  # @return [Hash] 月別統計
  def self.monthly_stats(user, months = 6)
    start_date = months.months.ago.beginning_of_month
    marks = user.reflection_marks.by_date_range(start_date, Date.current)

    (0...months).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_marks = marks.by_date_range(month_start, month_end)

      {
        month: month_start.strftime("%Y-%m"),
        total_marks: month_marks.count,
        by_type: month_marks.group(:mark_type).count,
        with_notes: month_marks.with_notes.count
      }
    end.reverse
  end

  # 人気のマークタイプを取得
  # @param [User] user ユーザー
  # @return [Array<Hash>] タイプと件数
  def self.popular_mark_types(user)
    user.reflection_marks
        .group(:mark_type)
        .count
        .sort_by { |_, count| -count }
        .map { |type, count| { type: type, count: count } }
  end

  # 連続マーク日数を計算
  # @param [User] user ユーザー
  # @param [Date] end_date 終了日
  # @return [Integer] 連続日数
  def self.calculate_streak(user, end_date = Date.current)
    streak = 0
    current_date = end_date

    while current_date >= 30.days.ago
      if user.reflection_marks.where(date: current_date).exists?
        streak += 1
        current_date -= 1.day
      else
        break
      end
    end

    streak
  end

  private

  # デフォルトマークタイプを設定
  def set_default_mark_type
    self.mark_type = "reflection"
  end
end
