module Command
  # Command handler (service object): declare with `handles CommandClass, :method`.
  module Handler
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def handles(command_class, method_name)
        command_handlers[command_class] = method_name
        Command.register(command_class, ->(command) { new.call(command) })
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
      public_send(method_name, command)
    end
  end
end
