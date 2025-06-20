class AiGoalInsight < ApplicationRecord
  belongs_to :user
  
  # バリデーション
  validates :title, presence: true
  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: %w[not_started in_progress completed paused] }
  
  # action_plan: Array (jsonb)
  # deadline: Date
  # progress_check: String
  # milestone: Date
  # status: String (not_started, in_progress, completed, paused)
  
  # スコープ
  scope :not_started, -> { where(status: 'not_started') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :paused, -> { where(status: 'paused') }
  scope :active, -> { where(status: ['not_started', 'in_progress']) }
  
  # インスタンスメソッド
  def not_started?
    status == 'not_started'
  end
  
  def in_progress?
    status == 'in_progress'
  end
  
  def completed?
    status == 'completed'
  end
  
  def paused?
    status == 'paused'
  end
  
  def can_start?
    not_started? || paused?
  end
  
  def can_complete?
    in_progress?
  end
  
  def can_pause?
    in_progress?
  end
end 