require "rails_event_store"
require "aggregate_root"

Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::JSONClient.new

  # Command bus middleware (see lib/command/): run each command in a database
  # transaction, publish instrumentation, and set up causation / correlation
  # ids for the events the command publishes.
  command_bus = Command::Bus.new
  command_bus.use(Command::Middleware::Transaction.new)
  command_bus.use(Command::Middleware::Instrumentation.new)
  command_bus.use(Command::Middleware::Causation.new(event_store: Rails.configuration.event_store))
  Rails.configuration.command_bus = command_bus

  # Use AggregateRoot::Repository with explicit event store injection, e.g.:
  #
  #   repository = AggregateRoot::Repository.new(Rails.configuration.event_store)
  #   repository.with_aggregate(Order.new(order_id), "Order$#{order_id}") do |order|
  #     order.submit
  #   end

  # Subscribe event handlers below
  Rails.configuration.event_store.tap do |store|
    # store.subscribe(InvoiceReadModel.new, to: [InvoicePrinted])
    # store.subscribe(lambda { |event| SendOrderConfirmation.new.call(event) }, to: [OrderSubmitted])
    # store.subscribe_to_all_events(lambda { |event| Rails.logger.info(event.event_type) })

    store.subscribe_to_all_events(RailsEventStore::LinkByEventType.new)
    store.subscribe_to_all_events(RailsEventStore::LinkByCorrelationId.new)
    store.subscribe_to_all_events(RailsEventStore::LinkByCausationId.new)
  end

  # Installs self-registered commands onto the bus and subscribes domain event
  # handlers contributed by domain modules.
  ApplicationSubscriptions.install(
    event_store: Rails.configuration.event_store,
    command_bus: Rails.configuration.command_bus
  )
end
