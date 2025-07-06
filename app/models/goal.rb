class Goal < ApplicationRecord
  belongs_to :user

  # バリデーション
  validates :title, presence: true
  validates :description, presence: true
  validates :deadline, presence: true
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # スコープ
  scope :active, -> { where("deadline >= ?", Date.current) }
  scope :completed, -> { where(progress: 100) }
  scope :overdue, -> { where("deadline < ? AND progress < 100", Date.current) }
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

  # アクションプラン関連メソッド
  def action_plan_items
    return [] unless action_plan.is_a?(Array)

    # 新形式（オブジェクト配列）の場合
    if action_plan.first.is_a?(Hash)
      action_plan
    else
      # 旧形式（文字列配列）の場合は変換
      action_plan.map.with_index do |title, index|
        {
          "id" => "action_#{index + 1}",
          "title" => title,
          "progress" => 0
        }
      end
    end
  end

  def update_action_plan_progress(action_id, progress)
    items = action_plan_items
    item = items.find { |item| item["id"] == action_id }
    return false unless item

    item["progress"] = progress.to_i.clamp(0, 100)
    self.action_plan = items
    save
  end

  def action_plan_overall_progress
    items = action_plan_items
    return 0 if items.empty?

    total_progress = items.sum { |item| item["progress"] || 0 }
    (total_progress.to_f / items.length).round
  end

  def completed_action_plans_count
    action_plan_items.count { |item| (item["progress"] || 0) == 100 }
  end

  def in_progress_action_plans_count
    action_plan_items.count { |item| (item["progress"] || 0) > 0 && (item["progress"] || 0) < 100 }
  end
end
