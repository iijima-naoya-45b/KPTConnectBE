class Goal < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :title, presence: true
  validates :description, presence: true
  validates :deadline, presence: true
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # スコープ
  scope :active, -> { where('deadline >= ?', Date.current) }
  scope :completed, -> { where(progress: 100) }
  scope :overdue, -> { where('deadline < ? AND progress < 100', Date.current) }
  scope :recent, -> { order(created_at: :desc) }

  # インスタンスメソッド
  def completed?
    progress == 100
  end

  def overdue?
    deadline < Date.current && !completed?
  end

  def days_remaining
    (deadline - Date.current).to_i
  end
end
