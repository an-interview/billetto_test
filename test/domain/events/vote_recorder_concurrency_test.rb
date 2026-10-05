require "test_helper"

# Votes from two connections racing for the same (event, user) must collapse to
# a single recorded vote. This class opts out of transactional tests because the
# race needs two real, independently committed connections.
class Events::VoteRecorderConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    @event = Event.create!(
      external_id: "concurrent-#{SecureRandom.hex(6)}",
      title: "Concurrent vote",
      starts_at: Time.zone.now
    )
    @stream = "Event$#{@event.id}"
    @user_id = "user_race"
  end

  def teardown
    remove_facts
    Event.where(id: @event.id).delete_all
    clear_enqueued_jobs
  end

  test "two near-simultaneous votes from the same user record one vote" do
    barrier = Concurrent::CyclicBarrier.new(2)

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait
          Rails.configuration.command_bus.call(
            Events::CastVote.new(tid: @event.tid, user_id: @user_id, direction: "up")
          )
        end
      end
    end
    threads.each(&:join)

    votes = Rails.configuration.event_store.read.stream(@stream).to_a
      .select { |fact| fact.event_type == "Events::EventUpvoted" }

    assert_equal 1, votes.size
    assert_equal @user_id, votes.first.payload.fetch(:user_id)
  end

  private

  def remove_facts
    connection = ApplicationRecord.connection
    event_ids = connection.select_values(
      ApplicationRecord.sanitize_sql_array(
        [ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", @stream ]
      )
    )
    return if event_ids.empty?

    connection.execute(
      ApplicationRecord.sanitize_sql_array(
        [ "DELETE FROM event_store_events_in_streams WHERE event_id IN (?)", event_ids ]
      )
    )
    connection.execute(
      ApplicationRecord.sanitize_sql_array(
        [ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ]
      )
    )
  end

  def clear_enqueued_jobs
    adapter = ActiveJob::Base.queue_adapter
    adapter.enqueued_jobs.clear if adapter.respond_to?(:enqueued_jobs)
  end
end
