module Command
  # Self-executing command: declare inputs with `attribute`, implement #call.
  module Executable
    def self.included(base)
      base.extend(ClassMethods)
      base.include(ActiveModel::Validations)
      # Prepended so it wins over ActiveModel's own #validate!.
      base.prepend(Validation)
      Command.register(base, ->(command) { command.call })
    end

    module Validation
      def validate!
        raise ValidationError, errors.full_messages.join(", ") if invalid?
        self
      end
    end

    module ClassMethods
      def attribute(name, type = Object, default: nil)
        attribute_definitions[name] = { type: type, default: default }
        attr_accessor name
      end

      def attribute_definitions
        @attribute_definitions ||=
          if superclass.respond_to?(:attribute_definitions)
            superclass.attribute_definitions.dup
          else
            {}
          end
      end
    end

    def initialize(**attributes)
      unknown = attributes.keys - self.class.attribute_definitions.keys
      raise ArgumentError, "unknown attributes: #{unknown.join(", ")}" if unknown.any?

      self.class.attribute_definitions.each do |name, definition|
        public_send("#{name}=", attributes.fetch(name, definition[:default]))
      end
    end
  end
end
