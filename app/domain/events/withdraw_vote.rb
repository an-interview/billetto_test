module Events
  # Removes the active vote that +user_id+ has on the event identified by +tid+.
  #
  # Withdrawal is idempotent: when the user has no active vote, the command
  # validates successfully and the handler records no fact.
  #
  # call-seq:
  #   command = Events::WithdrawVote.new(tid: "event_42", user_id: "user_1")
  #   command.validate!
  class WithdrawVote
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :tid, :string
    attribute :user_id, :string

    validates :tid, :user_id, presence: true

    # Raises Command::ValidationError when the command is invalid.
    #
    # Returns the command when valid so callers can chain.
    def validate!
      raise Command::ValidationError, errors.full_messages.join(", ") if invalid?

      self
    end
  end
end
