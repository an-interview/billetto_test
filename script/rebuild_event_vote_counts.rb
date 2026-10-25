# Rebuilds the EventVoteCounts read model from the event store.
#
# All vote facts, including withdrawals, are linked into Events::VOTES_STREAM,
# so a single stream read gives the facts the projection is built from. The
# projection is synchronous, so replaying the stream also rebuilds
# event_vote_states and event_vote_counts.
#
# Run with: bin/rails runner script/rebuild_event_vote_counts.rb
counts = ReadModels::EventVoteCounts.new
facts = Rails.configuration.event_store.read.stream(Events::VOTES_STREAM)

ReadModels::EventVoteCounts::State.delete_all
ReadModels::EventVoteCounts::Count.delete_all
ProcessedEvent.where(handler: ReadModels::EventVoteCounts.name).delete_all
facts.each { |fact| counts.call(fact) }

puts "Rebuilt #{ReadModels::EventVoteCounts::Count.count} vote count(s) and " \
     "#{ReadModels::EventVoteCounts::State.count} vote state(s) from #{facts.count} fact(s)"
