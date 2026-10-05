# Domain event base. Schema values are the expected class; wrap one in an
# Array to mark the key optional (e.g. `note: [String]`).
class Fact < RubyEventStore::Event
  NotDefined = Class.new(StandardError)
  InvalidData = Class.new(StandardError)

  SCHEMA = {}.freeze

  class << self
    def strict(data:, metadata: {}, event_id: nil)
      attributes = { data: coerce(data), metadata: metadata }
      attributes[:event_id] = event_id if event_id
      new(**attributes)
    end

    def schema
      self::SCHEMA
    end

    private

    def coerce(data)
      data = data.to_h.symbolize_keys
      unknown = data.keys - schema.keys
      raise InvalidData, "#{name}: unknown keys #{unknown.inspect}" if unknown.any?

      schema.each_with_object({}) do |(key, type), payload|
        optional = type.is_a?(Array)
        expected = optional ? type.first : type
        value = data[key]

        raise InvalidData, "#{name}: missing #{key}" if value.nil? && !optional
        unless value.nil? || value.is_a?(expected)
          raise InvalidData, "#{name}: #{key} must be a #{expected}, got #{value.class}"
        end

        payload[key] = value
      end
    end
  end

  def stream_names
    raise NotDefined, "#{self.class.name} must define #stream_names"
  end

  # Indifferent access, because JSON round-trips turn symbol keys into strings.
  def payload
    data.with_indifferent_access
  end
end
