module Billetto
  # Fetches public events from the Billetto API and returns raw event hashes.
  # Mapping them into domain objects is the caller's responsibility.
  class Adapter
    DEFAULT_BASE_URL = "https://billetto.dk/api/v3"

    TRANSPORT_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      OpenSSL::SSL::SSLError
    ].freeze

    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, http_client: HttpClient.new)
      @api_key = api_key
      @base_url = base_url
      @http_client = http_client
    end

    def list_public_events(limit: 10)
      body = get("public/events", limit: limit)
      events = body["data"]
      raise ResponseError, "expected a data array, got #{events.class}" unless events.is_a?(Array)

      events
    end

    private

    attr_reader :api_key, :base_url, :http_client

    def get(path, params)
      ensure_api_key!

      status, body =
        http_client.call(
          uri: build_uri(path, params),
          headers: headers,
          open_timeout: 5,
          read_timeout: 10
        )

      unless (200..299).cover?(status)
        raise RequestError, "Billetto returned #{status}: #{body.to_s[0, 200]}"
      end

      parse(body)
    rescue *TRANSPORT_ERRORS => error
      raise ConnectionError, error.message
    end

    def ensure_api_key!
      return if api_key.present?

      raise ConfigurationError, "BILLETTO_API_KEYPAIR is not set"
    end

    def build_uri(path, params)
      uri = URI.join("#{base_url.chomp("/")}/", path)
      uri.query = URI.encode_www_form(params)
      uri
    end

    def headers
      { "Api-Keypair" => api_key, "Accept" => "application/json" }
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError => error
      raise ResponseError, "invalid JSON: #{error.message}"
    end
  end
end
