module Command
  module Middleware
    # Publishes ActiveSupport instrumentation for every command execution.
    class Instrumentation
      EVENT = "command.executed"

      def initialize(notifier: ActiveSupport::Notifications)
        @notifier = notifier
      end

      def call(command, next_step)
        @notifier.instrument(EVENT, command: command, command_class: command.class.name) do
          next_step.call
        end
      end
    end
  end
end
