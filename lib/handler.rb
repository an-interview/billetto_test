# Event handler / process manager base.
#
#   include Handler                      # sync
#   include Handler.async(queue: "low")  # runs in a background job
#   subscribes_to SomeFact
#   def call(fact) ... end
module Handler
  class AsyncAdapter
    def initialize(handler_class, queue)
      @handler_class = handler_class
      @queue = queue
    end

    # Dispatch happens while the publishing command's transaction is still open
    # (the event store notifies subscribers synchronously during publish).
    # Enqueue only once that transaction commits, otherwise an in-process worker
    # can run on another connection and read the fact before it is committed —
    # seeing nothing. `current_transaction.after_commit` runs the block at once
    # when there is no open transaction.
    def call(fact)
      ApplicationRecord.current_transaction.after_commit do
        HandlerJob.set(queue: @queue).perform_later(@handler_class.name, fact.event_id)
      end
    end
  end

  module ClassMethods
    def subscribes_to(*fact_classes)
      @subscribed_facts = fact_classes
    end

    def subscribed_facts
      @subscribed_facts || []
    end

    def async_queue
      instance_variable_get(:@async_queue)
    end

    def async?
      !async_queue.nil?
    end

    def subscriptions
      subscribed_facts.each_with_object({}) do |fact_class, subscriptions|
        subscriptions[fact_class] = async? ? AsyncAdapter.new(self, async_queue) : new
      end
    end
  end

  extend ClassMethods

  def self.included(base)
    base.extend(ClassMethods)
  end

  def self.async(queue: "default")
    Module.new do
      define_singleton_method(:included) do |base|
        base.instance_variable_set(:@async_queue, queue)
        base.extend(ClassMethods)
      end
    end
  end
end
