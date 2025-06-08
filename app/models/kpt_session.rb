# frozen_string_literal: true

# KPTセッションモデル
#
# @description KPTセッションの管理を行うモデル
# セッション情報、ステータス管理、関連するKPTアイテムとの関連を定義
#
# @attr [Integer] user_id ユーザーID
# @attr [String] title セッションタイトル
# @attr [String] description セッション説明
# @attr [Date] session_date セッション実施日
# @attr [String] status ステータス (draft, in_progress, completed, archived)
# @attr [Array<String>] tags タグリスト
# @attr [Boolean] is_template テンプレートフラグ
# @attr [String] template_name テンプレート名
# @attr [DateTime] completed_at 完了日時
class KptSession < ApplicationRecord
  # リレーション
  belongs_to :user
  has_many :kpt_items, dependent: :destroy
  has_many :insights, dependent: :destroy
  has_many :work_log_kpt_links, dependent: :destroy
  has_many :work_logs, through: :work_log_kpt_links

  # バリデーション
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :status, inclusion: { in: %w[not_started in_progress completed pending] }
  validates :session_date, presence: true
  validates :template_name, length: { maximum: 100 }

  # 日本語⇔英語変換ヘルパー
  STATUS_LABELS = {
    "not_started" => "未着手",
    "in_progress" => "着手中",
    "completed"   => "完了",
    "pending"     => "保留"
  }.freeze

  def status_ja
    STATUS_LABELS[status] || status
  end

  def self.status_en(japanese)
    STATUS_LABELS.invert[japanese] || japanese
  end

  # スコープ
  scope :active, -> { where.not(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :recent, -> { order(session_date: :desc, created_at: :desc) }
  scope :templates, -> { where(is_template: true) }
  scope :not_templates, -> { where(is_template: false) }
  scope :by_date_range, ->(start_date, end_date) { where(session_date: start_date..end_date) }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :by_status, ->(status) { where(status: status) }

  # コールバック
  before_validation :set_session_date, unless: :session_date?
  after_update :update_completed_at, if: :completed_status_changed?

  # インスタンスメソッド

  # セッションが完了しているかチェック
  # @return [Boolean] 完了状態
  def completed?
    status == "completed"
  end

  # セッションがアクティブかチェック
  # @return [Boolean] アクティブ状態
  def active?
    status != "archived"
  end

  # セッション内のKPTアイテム数統計を取得
  # @return [Hash] 各タイプのアイテム数
  def kpt_items_count
    {
      keep: kpt_items.where(type: "keep").count,
      problem: kpt_items.where(type: "problem").count,
      try: kpt_items.where(type: "try").count,
      total: kpt_items.count
    }
  end

  # セッションの進捗率を計算
  # @return [Float] 進捗率 (0.0-1.0)
  def progress_rate
    return 0.0 if kpt_items.count.zero?

    completed_items = kpt_items.where(status: "completed").count
    completed_items.to_f / kpt_items.count
  end

  # セッションの感情スコア平均を計算
  # @return [Float, nil] 感情スコア平均
  def average_emotion_score
    scores = kpt_items.where.not(emotion_score: nil).pluck(:emotion_score)
    return nil if scores.empty?

    scores.sum.to_f / scores.size
  end

  # セッションのインパクトスコア平均を計算
  # @return [Float, nil] インパクトスコア平均
  def average_impact_score
    scores = kpt_items.where.not(impact_score: nil).pluck(:impact_score)
    return nil if scores.empty?

    scores.sum.to_f / scores.size
  end

  # セッションをテンプレートとして保存
  # @param [String] template_name テンプレート名
  # @return [KptSession] 新しいテンプレートセッション
  def save_as_template(template_name)
    template = self.class.new(
      user: user,
      title: "#{title} (テンプレート)",
      description: description,
      tags: tags,
      is_template: true,
      template_name: template_name,
      status: "draft"
    )

    if template.save
      # KPTアイテムもコピー
      kpt_items.each do |item|
        template.kpt_items.create!(
          type: item.type,
          content: item.content,
          priority: item.priority,
          tags: item.tags
        )
      end
    end

    template
  end

  # クラスメソッド

  # ユーザーの月別統計を取得
  # @param [User] user ユーザー
  # @param [Integer] months 月数
  # @return [Hash] 月別統計データ
  def self.monthly_stats(user, months = 6)
    start_date = months.months.ago.beginning_of_month
    sessions = user.kpt_sessions.by_date_range(start_date, Date.current)

    (0...months).map do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_sessions = sessions.by_date_range(month_start, month_end)

      {
        month: month_start.strftime("%Y-%m"),
        sessions_count: month_sessions.count,
        completed_count: month_sessions.completed.count,
        items_count: month_sessions.joins(:kpt_items).count
      }
    end.reverse
  end

  # 人気のタグを取得
  # @param [User] user ユーザー
  # @param [Integer] limit 取得件数
  # @return [Array<Hash>] タグと件数
  def self.popular_tags(user, limit = 10)
    user.kpt_sessions.where.not(tags: [])
        .pluck(:tags)
        .flatten
        .tally
        .sort_by { |_, count| -count }
        .first(limit)
        .map { |tag, count| { tag: tag, count: count } }
  end

  private

  # セッション日を設定
  def set_session_date
    self.session_date = Date.current
  end

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
end
