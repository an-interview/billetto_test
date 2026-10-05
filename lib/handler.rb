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

    def call(fact)
      HandlerJob.set(queue: @queue).perform_later(@handler_class.name, fact.event_id)
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
