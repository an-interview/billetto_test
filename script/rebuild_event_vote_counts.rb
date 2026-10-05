# Rebuilds the EventVoteCounts read model from the event store.
#
# Run with: bin/rails runner script/rebuild_event_vote_counts.rb
counts = ReadModels::EventVoteCounts.new
facts = Rails.configuration.event_store.read.of_type(
  [ Events::EventUpvoted, Events::EventDownvoted ]
)

ReadModels::EventVoteCounts::Count.delete_all
facts.each { |fact| counts.call(fact) }

puts "Rebuilt #{ReadModels::EventVoteCounts::Count.count} vote count(s) from #{facts.count} fact(s)"
