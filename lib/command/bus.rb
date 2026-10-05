module Command
  # Dispatches commands through a chain of middleware and then to the registered
  # handler.
  #
  # Middleware are added with #use in outer-to-inner order and wrap the whole
  # command execution (transactions, instrumentation, causation/correlation
  # setup). See Command::Middleware.
  class Bus
    def initialize
      @handlers = {}
      @middlewares = []
    end

    def use(middleware)
      @middlewares << middleware
      self
    end

    def register(command_class, handler)
      @handlers[command_class] = handler
      self
    end

    def call(command)
      handler = @handlers.fetch(command.class) do
        raise Command::Error, "no handler registered for #{command.class.name}"
      end

      @middlewares.reverse.inject(-> { handler.call(command) }) do |next_step, middleware|
        -> { middleware.call(command, next_step) }
      end.call
    end
  end
end
