# Application read models: projections of domain events into tables ready to be
# queried by the presentation layer.
module ReadModels
  # Referenced so Zeitwerk loads the classes and their `subscribes_to` runs.
  def self.load!
    [ EventVoteCounts, CurrentVote ]
    self
  end

  def self.subscriptions
    [ EventVoteCounts ].map(&:subscriptions).reduce({}, :merge)
  end
end
