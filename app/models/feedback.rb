# frozen_string_literal: true

# フィードバックモデル
#
# @description ユーザーからのフィードバック情報を管理するメインモデル
# helpページから送信されるバグ報告、機能リクエスト等のフィードバックを管理
#
# @attr [Integer] user_id ユーザーID
# @attr [Integer] feedback_type_id フィードバック種別ID
# @attr [Integer] feedback_priority_id フィードバック優先度ID
# @attr [String] title フィードバックタイトル
# @attr [String] description フィードバック詳細説明
# @attr [String] email フィードバック送信者メールアドレス
# @attr [String] status ステータス（unread/in_progress/resolved）
# @attr [String] admin_notes 管理者メモ
# @attr [DateTime] resolved_at 解決日時
# @attr [JSON] metadata 追加データ
# @attr [Boolean] is_active アクティブ状態
class Feedback < ApplicationRecord
  # リレーション
  belongs_to :user
  belongs_to :feedback_type
  belongs_to :feedback_priority

  # 定数定義
  STATUSES = %w[unread in_progress resolved].freeze

  # バリデーション
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true, length: { maximum: 10_000 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :admin_notes, length: { maximum: 5_000 }, allow_blank: true

  # バリデーション（カスタム）
  validate :resolved_at_presence_when_resolved

  # スコープ
  scope :active, -> { where(is_active: true) }
  scope :unread, -> { where(status: 'unread') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority, -> { joins(:feedback_priority).order('feedback_priorities.priority_level DESC') }
  scope :high_priority, -> { joins(:feedback_priority).where('feedback_priorities.priority_level >= 3') }

  # スコープ（日付範囲）
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(created_at: 1.month.ago..Time.current) }

  # コールバック
  before_save :set_resolved_at_on_status_change

  # クラスメソッド

  # フィードバック統計情報を取得
  # @return [Hash] 統計データ
  def self.statistics
    {
      total: count,
      unread: unread.count,
      in_progress: in_progress.count,
      resolved: resolved.count,
      today: today.count,
      this_week: this_week.count,
      this_month: this_month.count,
      high_priority_unread: high_priority.unread.count
    }
  end

  # 最新のフィードバックを取得
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] フィードバック配列
  def self.recent_feedbacks(limit = 10)
    includes(:user, :feedback_type, :feedback_priority)
      .active
      .recent
      .limit(limit)
  end

  # 優先度別のフィードバック一覧を取得
  # @param [String] priority_key 優先度キー
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] フィードバック配列
  def self.by_priority_key(priority_key, limit = 50)
    joins(:feedback_priority)
      .where(feedback_priorities: { key: priority_key })
      .includes(:user, :feedback_type, :feedback_priority)
      .active
      .recent
      .limit(limit)
  end

  # 種別別のフィードバック一覧を取得
  # @param [String] type_key 種別キー
  # @param [Integer] limit 取得件数
  # @return [ActiveRecord::Relation] フィードバック配列
  def self.by_type_key(type_key, limit = 50)
    joins(:feedback_type)
      .where(feedback_types: { key: type_key })
      .includes(:user, :feedback_type, :feedback_priority)
      .active
      .recent
      .limit(limit)
  end

  # ダッシュボード用サマリーデータを取得
  # @return [Hash] ダッシュボードサマリー
  def self.dashboard_summary
    {
      overview: statistics,
      recent_feedbacks: recent_feedbacks(5),
      high_priority_items: high_priority.unread.limit(3),
      type_breakdown: FeedbackType.statistics,
      priority_breakdown: FeedbackPriority.statistics
    }
  end

  # インスタンスメソッド

  # フィードバックの表示タイトルを取得
  # @return [String] 表示タイトル
  def display_title
    title.truncate(50)
  end

  # フィードバックの表示説明を取得
  # @param [Integer] length 文字数制限
  # @return [String] 表示説明
  def display_description(length = 100)
    description.truncate(length)
  end

  # 未読かどうかをチェック
  # @return [Boolean] 未読状態
  def unread?
    status == 'unread'
  end

  # 対応中かどうかをチェック
  # @return [Boolean] 対応中状態
  def in_progress?
    status == 'in_progress'
  end

  # 解決済みかどうかをチェック
  # @return [Boolean] 解決済み状態
  def resolved?
    status == 'resolved'
  end

  # 高優先度かどうかをチェック
  # @return [Boolean] 高優先度判定
  def high_priority?
    feedback_priority&.high_priority?
  end

  # 作成からの経過時間を取得
  # @return [String] 経過時間の文字列
  def time_since_created
    time_ago_in_words(created_at) + '前'
  end

  # 解決までの所要時間を取得
  # @return [String, nil] 所要時間の文字列
  def resolution_time
    return nil unless resolved? && resolved_at

    distance_of_time_in_words(created_at, resolved_at)
  end

  # フィードバックのメタデータを取得
  # @param [String] key メタデータキー
  # @return [String, nil] メタデータ値
  def get_metadata(key)
    metadata&.dig(key)
  end

  # フィードバックのメタデータを設定
  # @param [String] key メタデータキー
  # @param [String] value メタデータ値
  def set_metadata(key, value)
    self.metadata ||= {}
    self.metadata[key] = value
  end

  # ステータスを変更
  # @param [String] new_status 新しいステータス
  # @param [String] notes 管理者メモ
  # @return [Boolean] 保存結果
  def change_status(new_status, notes = nil)
    self.status = new_status
    self.admin_notes = notes if notes.present?
    save
  end

  # フィードバックを解決済みにマーク
  # @param [String] notes 管理者メモ
  # @return [Boolean] 保存結果
  def mark_as_resolved(notes = nil)
    change_status('resolved', notes)
  end

  # フィードバックを対応中にマーク
  # @param [String] notes 管理者メモ
  # @return [Boolean] 保存結果
  def mark_as_in_progress(notes = nil)
    change_status('in_progress', notes)
  end

  private

  # ステータスが解決済みの場合にresolved_atが設定されているかをチェック
  def resolved_at_presence_when_resolved
    if status == 'resolved' && resolved_at.blank?
      errors.add(:resolved_at, 'は解決済みの場合は必須です')
    end
  end

  # ステータス変更時にresolved_atを自動設定
  def set_resolved_at_on_status_change
    if status_changed?
      if status == 'resolved' && resolved_at.blank?
        self.resolved_at = Time.current
      elsif status != 'resolved'
        self.resolved_at = nil
      end
    end
  end
end 