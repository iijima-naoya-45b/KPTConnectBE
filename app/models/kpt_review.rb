class KptReview < ApplicationRecord
  belongs_to :user
  validates :title, :description, :keep, :problem, :try, :user_id, presence: true
end
