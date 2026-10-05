module Command
  # Command handler (service object): declare with `handles CommandClass, :method`.
  module Handler
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Declares that this service handles a command. The registration on the
      # command bus happens in ApplicationSubscriptions#register_commands, per
      # the developer guide (executable commands self-register instead).
      def handles(command_class, method_name)
        command_handlers[command_class] = method_name
      end

      def command_handlers
        @command_handlers ||=
          if superclass.respond_to?(:command_handlers)
            superclass.command_handlers.dup
          else
            {}
          end
      end
    end

    def call(command)
      method_name = self.class.command_handlers.fetch(command.class) do
        raise Command::Error, "#{self.class.name} cannot handle #{command.class.name}"
      end
      send(method_name, command)
    end
  end
end
