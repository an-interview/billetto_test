module Command
  module Middleware
    # Sets the causation and correlation ids for the events a command publishes.
    #
    # Uses the event store's request-metadata mechanism, which also drives the
    # LinkByCorrelationId / LinkByCausationId subscriptions.
    #
    # When the command is dispatched from within a domain event handler, the
    # event store has already populated both ids for the handled event
    # (correlation = the handled event's correlation id, causation = the handled
    # event's id), so we inherit them. For a top-level command we start a new
    # correlation id and use a fresh id as the command's causation id.
    class Causation
      def initialize(event_store: Rails.configuration.event_store)
        @event_store = event_store
      end

      def call(_command, next_step)
        return next_step.call if @event_store.metadata[:correlation_id]

        @event_store.with_metadata(
          correlation_id: SecureRandom.uuid,
          causation_id: SecureRandom.uuid
        ) { next_step.call }
      end
    end
  end
end
