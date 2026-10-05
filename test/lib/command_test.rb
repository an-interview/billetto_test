require "test_helper"

class CommandTest < ActiveSupport::TestCase
  class Greet
    include Command::Executable
    attribute :name, String
    validates :name, presence: true

    def call
      "hello #{name}"
    end
  end

  class Record
    include Command::Executable

    def call
      "direct"
    end
  end

  class RecordingService
    include Command::Handler
    handles Record, :record

    def record(_command)
      "via service"
    end
  end

  setup do
    @registry = Command.handlers.dup
  end

  teardown do
    Command.handlers.replace(@registry) if @registry
  end

  test "executable command exposes attributes" do
    assert_equal "ada", Greet.new(name: "ada").name
  end

  test "executable command rejects unknown attributes" do
    assert_raises(ArgumentError) { Greet.new(nope: 1) }
  end

  test "validate! raises for invalid command" do
    assert_raises(Command::ValidationError) { Greet.new(name: "").validate! }
  end

  test "install registers executable commands on the bus" do
    bus = Command::Bus.new
    Command.install(bus)

    assert_equal "hello ada", bus.call(Greet.new(name: "ada"))
  end

  test "register_commands registers service handlers on the bus" do
    bus = Command::Bus.new
    ApplicationSubscriptions.register_commands(bus, handler_classes: [ RecordingService ])

    assert_equal "via service", bus.call(Record.new)
  end

  test "handler rejects unknown commands" do
    assert_raises(Command::Error) { RecordingService.new.call(Object.new) }
  end
end
