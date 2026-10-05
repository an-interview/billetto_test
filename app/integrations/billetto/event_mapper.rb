module Billetto
  # Translates a raw API event payload into attributes for the Event model.
  module EventMapper
    module_function

    def to_attributes(payload)
      payload = payload.with_indifferent_access

      {
        external_id: payload[:id]&.to_s,
        title: payload[:title],
        description: payload[:description],
        url: payload[:url],
        image_url: payload[:image_link],
        starts_at: parse_time(payload[:startdate]),
        ends_at: parse_time(payload[:enddate]),
        state: payload[:state],
        event_type: payload.dig(:categorization, :type) || payload[:type],
        organizer_id: (payload.dig(:organiser, :id) || payload.dig(:organizer, :id))&.to_s,
        organizer_name: payload.dig(:organiser, :name) || payload.dig(:organizer, :name),
        venue: payload.dig(:location, :location_name),
        city: payload.dig(:location, :city),
        country_code: payload.dig(:location, :country_code),
        availability: ActiveModel::Type::Boolean.new.cast(payload[:availability]) || false
      }
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
