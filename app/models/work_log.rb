
class WorkLog < ApplicationRecord
  belongs_to :user
  has_many :work_log_kpt_links, dependent: :destroy
  has_many :kpt_sessions, through: :work_log_kpt_links
  # バリデーション
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }
  validates :category, length: { maximum: 100 }
  validates :project_name, length: { maximum: 100 }
  validates :started_at, presence: true
  validates :mood_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :productivity_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :difficulty_score, inclusion: { in: 1..5 }, allow_nil: true
  validates :status, inclusion: { in: %w[in_progress completed paused cancelled] }
  validates :location, length: { maximum: 100 }
  # スコープ
  scope :active, -> { where.not(status: 'cancelled') }
  scope :completed, -> { where(status: 'completed') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :by_date_range, ->(start_date, end_date) { where(started_at: start_date..end_date) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_project, ->(project) { where(project_name: project) }
  scope :billable, -> { where(is_billable: true) }
  scope :with_tag, ->(tag) { where('? = ANY(tags)', tag) }
  scope :recent, -> { order(started_at: :desc) }

  def duration_minutes
    return 0 unless started_at && ended_at
    
    ((ended_at - started_at) / 1.minute).round
  end

  def duration_hours
    duration_minutes / 60.0
  end

  def completed?
    status == 'completed'
  end

  def in_progress?
    status == 'in_progress'
  end

  def average_score
    scores = [mood_score, productivity_score, difficulty_score].compact
    return nil if scores.empty?
    
    scores.sum.to_f / scores.size
  end

  def complete!
    update!(status: 'completed', ended_at: Time.current)
  end

  # KPTセッションとリンク
  def link_to_kpt_session(kpt_session, options = {})
    work_log_kpt_links.create!(
      kpt_session: kpt_session,
      relevance_score: options[:relevance_score] || 3,
      notes: options[:notes]
    )
  end

  # ユーザーの作業統計を取得
  def self.stats_for_user(user, days = 30)
    start_date = days.days.ago
    logs = user.work_logs.by_date_range(start_date, Time.current)

    {
      total_logs: logs.count,
      completed_logs: logs.completed.count,
      total_hours: logs.sum(&:duration_hours),
      average_productivity: logs.where.not(productivity_score: nil).average(:productivity_score)&.round(2),
      popular_categories: logs.group(:category).count.sort_by { |_, count| -count }.first(5)
    }
  end
end 