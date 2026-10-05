module EventStoreInjector
  def event_store
    Rails.configuration.event_store
  end
end
