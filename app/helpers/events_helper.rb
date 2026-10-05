module EventsHelper
  # Multi-day events show a range; single-day events show one date.
  def event_date(event)
    return l(event.starts_at, format: :long) if event.ends_at.blank?
    return l(event.starts_at, format: :long) if event.ends_at.to_date == event.starts_at.to_date

    "#{l(event.starts_at, format: :long)} – #{l(event.ends_at, format: :long)}"
  end
end
