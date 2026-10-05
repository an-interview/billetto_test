require "test_helper"

class CommandBusTest < ActiveSupport::TestCase
  class Cmd; end

  class SampleFact < Fact
    SCHEMA = { value: Integer }.freeze

    def stream_names
      [ "BusTest$1" ]
    end
  end

  def bus(*middlewares)
    Command::Bus.new.tap { |bus| middlewares.each { |middleware| bus.use(middleware) } }
  end

  def stream
    Rails.configuration.event_store.read.stream("BusTest$1").to_a
  end

  test "raises when no handler is registered" do
    assert_raises(Command::Error) { Command::Bus.new.call(Cmd.new) }
  end

  test "runs the registered handler" do
    calls = []
    bus = bus()
    bus.register(Cmd, ->(command) { calls << command })

    command = Cmd.new
    bus.call(command)

    assert_equal [ command ], calls
  end

  test "transaction middleware rolls back the command's writes" do
    failing = bus(Command::Middleware::Transaction.new)
    failing.register(Cmd, lambda { |_command|
      SampleFact.strict(data: { value: 1 }).publish
      raise "boom"
    })

    assert_raises(RuntimeError) { failing.call(Cmd.new) }
    assert_empty stream
  end

  test "transaction middleware commits on success" do
    bus = bus(Command::Middleware::Transaction.new)
    bus.register(Cmd, ->(_command) { SampleFact.strict(data: { value: 1 }).publish })

    bus.call(Cmd.new)

    assert_equal 1, stream.size
  end

  test "instrumentation middleware publishes a notification" do
    notifications = []
    subscriber = ActiveSupport::Notifications.subscribe("command.executed") do |*args|
      notifications << ActiveSupport::Notifications::Event.new(*args)
    end

    bus = bus(Command::Middleware::Instrumentation.new)
    bus.register(Cmd, ->(_command) { :ok })
    bus.call(Cmd.new)

    assert_equal [ "CommandBusTest::Cmd" ], notifications.map { |e| e.payload[:command_class] }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "causation middleware starts one correlation for a top-level command" do
    bus = bus(Command::Middleware::Causation.new(event_store: Rails.configuration.event_store))
    bus.register(Cmd, lambda { |_command|
      2.times { SampleFact.strict(data: { value: 1 }).publish }
    })

    bus.call(Cmd.new)

    facts = stream
    assert_equal 2, facts.size
    assert_equal 1, facts.map { |f| f.metadata[:correlation_id] }.uniq.size
    assert facts.first.metadata[:correlation_id].present?
    assert facts.first.metadata[:causation_id].present?
  end

  test "causation middleware inherits ids when dispatched from an event handler" do
    event_store = Rails.configuration.event_store
    event_store.with_metadata(correlation_id: "corr-1", causation_id: "cause-1") do
      bus = bus(Command::Middleware::Causation.new(event_store: event_store))
      bus.register(Cmd, ->(_command) { SampleFact.strict(data: { value: 1 }).publish })
      bus.call(Cmd.new)
    end

    fact = stream.first
    assert_equal "corr-1", fact.metadata[:correlation_id]
    assert_equal "cause-1", fact.metadata[:causation_id]
  end
end
