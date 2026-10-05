Rails.configuration.to_prepare do
  Rails.configuration.billetto =
    if Rails.env.test?
      Billetto::FakeAdapter.new
    else
      Billetto::Adapter.new(
        api_key: ENV["BILLETTO_API_KEYPAIR"],
        base_url: ENV.fetch("BILLETTO_API_BASE_URL", Billetto::Adapter::DEFAULT_BASE_URL)
      )
    end
end
