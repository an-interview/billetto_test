# Bounded context for Billetto events: ingestion, listing and voting.
module Events
  # Stream that collects every vote fact, so the vote-count read model can be
  # rebuilt by reading a single stream (see script/rebuild_event_vote_counts.rb).
  VOTES_STREAM = "EventVotes".freeze

  # Event handlers / process managers owned by this module. There are none yet:
  # the module publishes facts that the application read models consume (see
  # ReadModels).
  EVENT_HANDLERS = [].freeze

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
    EVENT_HANDLERS.map(&:subscriptions).reduce({}, :merge)
  end
end
