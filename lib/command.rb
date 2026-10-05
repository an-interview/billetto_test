module Command
  Error = Class.new(StandardError)
  ValidationError = Class.new(Error)

  @handlers = {}

  class << self
    def handlers
      @handlers
    end

    def register(command_class, handler)
      @handlers[command_class] = handler
    end

    def install(bus)
      @handlers.each { |command_class, handler| bus.register(command_class, handler) }
      bus
    end

    def clear!
      @handlers.clear
    end
  end
end
