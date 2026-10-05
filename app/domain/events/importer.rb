module Events
  # Fetches public events through the Billetto adapter and upserts them as
  # Event records, publishing an EventImported fact for every new or changed
  # event. Invalid payloads are counted and skipped.
  class Importer
    include Command::Handler

    handles ImportPublicEvents, :import

    Result = Data.define(:imported, :skipped)

    def initialize(adapter: Billetto.adapter)
      @adapter = adapter
    end

    private

    attr_reader :adapter

    def import(command)
      command.validate!

      imported = 0
      skipped = 0

      adapter.list_public_events(limit: command.limit).each do |payload|
        case upsert(Billetto::EventMapper.to_attributes(payload))
        when :imported then imported += 1
        when :skipped then skipped += 1
        end
      end

      Result.new(imported: imported, skipped: skipped)
    end

    def upsert(attributes)
      event = Event.find_or_initialize_by(external_id: attributes[:external_id])
      event.assign_attributes(attributes)
      return :skipped unless event.valid?
      return :unchanged unless event.new_record? || event.changed?

      event.save!
      publish(event)
      :imported
    end

    def publish(event)
      EventImported.strict(
        data: { event_id: event.id, external_id: event.external_id }
      ).publish
    end
  end
end
