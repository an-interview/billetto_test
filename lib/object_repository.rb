# Maps aggregate type ids (e.g. "event_1") to their classes.
module ObjectRepository
  Error = Class.new(StandardError)
  UnknownType = Class.new(StandardError)

  @types = {}

  class << self
    def register(type_id, klass)
      @types[type_id.to_s] = klass
    end

    def registered(type_id)
      @types.fetch(type_id.to_s) do
        raise UnknownType, "no type registered for #{type_id}"
      end
    end

    def find(tid)
      type_id, id = tid.to_s.split("_", 2)
      registered(type_id).find(id)
    end
  end

  module HasTypeid
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def has_typeid(type_id)
        ObjectRepository.register(type_id, self)
        prefix = type_id.to_s
        define_method(:tid) { "#{prefix}_#{id}" }
      end
    end
  end
end
