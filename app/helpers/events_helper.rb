module EventsHelper
  # Multi-day events show a range; single-day events show one date.
  def event_date(event)
    return l(event.starts_at, format: :long) if event.ends_at.blank?
    return l(event.starts_at, format: :long) if event.ends_at.to_date == event.starts_at.to_date

    "#{l(event.starts_at, format: :long)} – #{l(event.ends_at, format: :long)}"
  end

  def event_upvotes(count)
    count ? count.upvotes : 0
  end

  def event_downvotes(count)
    count ? count.downvotes : 0
  end

  def event_total_votes(count)
    count ? count.upvotes + count.downvotes : 0
  end
end
