module Events
  # Cast a like ("up") or dislike ("down") on an event on behalf of a user.
  class CastVote
    include ActiveModel::Model
    include ActiveModel::Attributes

    DIRECTIONS = %w[up down].freeze

    attribute :tid, :string
    attribute :user_id, :string
    attribute :direction, :string

    validates :tid, :user_id, presence: true
    validates :direction, inclusion: { in: DIRECTIONS }

    def validate!
      raise Command::ValidationError, errors.full_messages.join(", ") if invalid?

      self
    end

    def up?
      direction == "up"
    end
  end
end
