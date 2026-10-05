class Event < ApplicationRecord
  has_typeid :event

  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :starts_at, presence: true
  validate :ends_at_after_starts_at

  scope :ordered, -> { order(:starts_at) }

  private

  def ends_at_after_starts_at
    return if ends_at.blank? || starts_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must be after starts_at")
  end
end
