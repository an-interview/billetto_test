require "test_helper"

class HandlerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class HandlerSampleFact < Fact
    SCHEMA = { value: Integer }.freeze

    def stream_names
      [ "HandlerSample$1" ]
    end
  end

  class SyncHandler
    include Handler
    subscribes_to HandlerSampleFact

    CALLS = []

    def call(fact)
      CALLS << fact.payload.fetch(:value)
    end
  end

  class AsyncHandler
    include Handler.async(queue: "low")
    subscribes_to HandlerSampleFact

    CALLS = []

    def call(fact)
      CALLS << fact.payload.fetch(:value)
    end
  end

  setup do
    SyncHandler::CALLS.clear
    AsyncHandler::CALLS.clear
  end

  test "sync handler subscriptions return the instance" do
    handler = SyncHandler.subscriptions.fetch(HandlerSampleFact)

    assert_instance_of SyncHandler, handler
    refute SyncHandler.async?
  end

  test "async handler subscriptions return an adapter and record the queue" do
    assert AsyncHandler.async?
    assert_equal "low", AsyncHandler.async_queue
    assert_instance_of Handler::AsyncAdapter, AsyncHandler.subscriptions.fetch(HandlerSampleFact)
  end

  test "async handler enqueues the backend job" do
    fact = HandlerSampleFact.strict(data: { value: 7 })
    adapter = AsyncHandler.subscriptions.fetch(HandlerSampleFact)

    assert_enqueued_with(job: HandlerJob, queue: "low") { adapter.call(fact) }
  end

  test "the job reads the event back and runs the handler" do
    fact = HandlerSampleFact.strict(data: { value: 9 })
    Rails.configuration.event_store.publish(fact, stream_name: "HandlerSample$1")

    AsyncHandler.subscriptions.fetch(HandlerSampleFact).call(fact)
    perform_enqueued_jobs

    assert_equal [ 9 ], AsyncHandler::CALLS
  end
end
