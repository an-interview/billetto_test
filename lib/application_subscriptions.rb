# Wires command handlers and event subscriptions at boot.
class ApplicationSubscriptions
  class << self
    def handlers
      top_level_subscriptions
        .merge(Events.subscriptions)
        .merge(ReadModels.subscriptions)
    end

    def top_level_subscriptions
      {}
    end

    def domain_modules
      [ Events, ReadModels ]
    end

    # Non-executable commands are dispatched by service objects (command
    # handlers) declared with `handles`. They are registered here; executable
    # commands self-register and are installed by Command.install.
    def register_commands(command_bus, handler_classes: command_handler_classes)
      handler_classes.each do |handler_class|
        handler_class.command_handlers.each_key do |command_class|
          command_bus.register(command_class, ->(command) { handler_class.new.call(command) })
        end
      end
      command_bus
    end

    def command_handler_classes
      [ Events::Importer, Events::VoteRecorder ]
    end

    # Loads domain modules so their commands and handlers self-register with
    # Command before the bus is populated.
    def load!
      domain_modules.each(&:load!)
      handlers
      self
    end

    def install(event_store:, command_bus:)
      load!
      Command.install(command_bus)
      register_commands(command_bus)
      handlers.each do |fact_class, handler|
        event_store.subscribe(handler, to: [ fact_class ])
      end
    end
  end
end
