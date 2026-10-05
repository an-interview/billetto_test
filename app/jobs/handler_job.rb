# Runs an async Handler in the background, re-reading the event by id.
class HandlerJob < ApplicationJob
  def perform(handler_class_name, event_id)
    event = Rails.configuration.event_store.read.event(event_id)
    return if event.nil?

    handler_class_name.constantize.new.call(event)
  end
end
