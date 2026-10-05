module Events
  # Command to ingest public events from the Billetto API.
  class ImportPublicEvents
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :limit, :integer, default: 50

    validates :limit, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

    def validate!
      raise Command::ValidationError, errors.full_messages.join(", ") if invalid?

      self
    end
  end
end
