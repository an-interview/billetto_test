require "test_helper"

# The read-model handlers are enqueued while the publishing command's
# transaction is still open. An in-process worker on another connection can then
# read the fact before it is committed and see nothing, so the enqueue must wait
# for the commit. This class opts out of transactional tests because the
# deferral only happens inside a real, joinable transaction.
class Handler::AsyncAdapterTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class RecordingHandler
    def call(fact); end
  end

  include ActiveJob::TestHelper

  def fact
    Events::EventUpvoted.strict(data: { event_id: 1, user_id: "u" })
  end

  def adapter
    Handler::AsyncAdapter.new(RecordingHandler, "low")
  end

  test "enqueues immediately when there is no open transaction" do
    assert_enqueued_with(job: HandlerJob) { adapter.call(fact) }
  end

  test "defers the enqueue until the surrounding transaction commits" do
    vote = fact

    ApplicationRecord.transaction do
      adapter.call(vote)

      assert_enqueued_jobs 0
    end

    assert_enqueued_jobs 1
    assert_enqueued_with(job: HandlerJob, args: [ RecordingHandler.name, vote.event_id ])
  end
end
