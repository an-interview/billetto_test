# Runs an async Handler in the background, re-reading the event by id.
class HandlerJob < ApplicationJob
  def perform(handler_class_name, event_id)
    event = Rails.configuration.event_store.read.event(event_id)
    return if event.nil?

    # Re-establish the causing event's correlation / causation context so events
    # or commands dispatched by the handler stay on the same trail.
    Rails.configuration.event_store.with_metadata(
      correlation_id: event.metadata[:correlation_id],
      causation_id: event.event_id
    ) do
      handler_class_name.constantize.new.call(event)
    end
  end
end
