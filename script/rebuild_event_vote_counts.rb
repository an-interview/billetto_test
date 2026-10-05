# Rebuilds the EventVoteCounts read model from the event store.
#
# All vote facts are linked into Events::VOTES_STREAM, so a single stream read
# gives the facts the read model is built from.
#
# Run with: bin/rails runner script/rebuild_event_vote_counts.rb
counts = ReadModels::EventVoteCounts.new
facts = Rails.configuration.event_store.read.stream(Events::VOTES_STREAM)

ReadModels::EventVoteCounts::Count.delete_all
ProcessedEvent.where(handler: ReadModels::EventVoteCounts.name).delete_all
facts.each { |fact| counts.call(fact) }

puts "Rebuilt #{ReadModels::EventVoteCounts::Count.count} vote count(s) from #{facts.count} fact(s)"
