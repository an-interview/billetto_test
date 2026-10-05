# Wires command handlers and event subscriptions at boot.
class ApplicationSubscriptions
  class << self
    def handlers
      top_level_subscriptions
    end

    def top_level_subscriptions
      {}
    end

    # Touching `handlers` forces autoloaded domain modules to load, so their
    # commands and handlers self-register with Command.
    def load!
      handlers
      self
    end

    def install(event_store:, command_bus:)
      load!
      Command.install(command_bus)
      handlers.each do |fact_class, handler|
        event_store.subscribe(handler, to: [ fact_class ])
      end
    end
  end
end
