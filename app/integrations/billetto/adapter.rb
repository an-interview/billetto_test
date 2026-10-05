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
      events = []
      body = get("public/events", limit: limit)
      visited = {}

      loop do
        events.concat(events_from(body))

        break unless body["has_more"]

        next_url = body["next_url"]
        break if next_url.blank?
        break if visited.key?(next_url)

        visited[next_url] = true
        body = get_url(next_url)
      end

      events
    end

    private

    attr_reader :api_key, :base_url, :http_client

    def events_from(body)
      events = body["data"]
      raise ResponseError, "expected a data array, got #{events.class}" unless events.is_a?(Array)

      events
    end

    def get(path, params)
      request(build_uri(path, params))
    end

    # Follows a `next_url` from the API, which may be absolute or relative,
    # carrying the `after` cursor. Refuses to leave the configured host so the
    # API keypair header is never sent elsewhere.
    def get_url(url)
      uri = URI.join("#{base_url.chomp("/")}/", url)
      return request(uri) if uri.host == URI.parse(base_url).host

      raise ResponseError, "refusing to follow next_url to #{uri.host}"
    end

    def request(uri)
      ensure_api_key!

      status, body =
        http_client.call(
          uri: uri,
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
