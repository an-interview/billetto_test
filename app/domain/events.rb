# Bounded context for Billetto events: ingestion, listing and voting.
module Events
  # Referenced so Zeitwerk loads the classes, letting the command handler
  # self-register with the command bus.
  def self.load!
    [
      ImportPublicEvents,
      Importer,
      EventImported,
      CastVote,
      VoteRecorder,
      EventUpvoted,
      EventDownvoted
    ]
    self
  end

  # Handler subscriptions contributed to ApplicationSubscriptions.
  def self.subscriptions
    [].map(&:subscriptions).reduce({}, :merge)
  end
end
