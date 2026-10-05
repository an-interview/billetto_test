require "test_helper"

class Billetto::AdapterTest < ActiveSupport::TestCase
  # Stand-in for Billetto::HttpClient that records the request and returns a
  # canned response (or raises).
  class Recorder
    attr_reader :last_call

    def initialize(status:, body:, error: nil)
      @status = status
      @body = body
      @error = error
    end

    def call(**kwargs)
      @last_call = kwargs
      raise @error if @error

      [ @status, @body ]
    end
  end

  # Returns a queued response per call and records every request, so a test can
  # exercise multi-page responses.
  class Sequence
    attr_reader :calls

    def initialize(*responses)
      @responses = responses
      @calls = []
    end

    def call(**kwargs)
      @calls << kwargs
      @responses.shift
    end
  end

  def adapter(client:, api_key: "test-key")
    Billetto::Adapter.new(api_key: api_key, http_client: client)
  end

  test "returns the data array on success" do
    client = Recorder.new(status: 200, body: { "data" => [ { "id" => "1" } ] }.to_json)

    assert_equal [ { "id" => "1" } ], adapter(client: client).list_public_events
  end

  test "sends the api key pair header to the public events endpoint" do
    client = Recorder.new(status: 200, body: { "data" => [] }.to_json)
    adapter(client: client, api_key: "secret").list_public_events

    assert_equal "secret", client.last_call[:headers]["Api-Keypair"]
    assert_equal "/api/v3/public/events", client.last_call[:uri].path
    assert_equal "limit=10", client.last_call[:uri].query
  end

  test "follows next_url until has_more is false" do
    first = {
      "data" => [ { "id" => "1" } ],
      "has_more" => true,
      "next_url" => "https://billetto.dk/api/v3/public/events?limit=1&after=abc"
    }
    second = { "data" => [ { "id" => "2" } ], "has_more" => false }
    client = Sequence.new([ 200, first.to_json ], [ 200, second.to_json ])

    events = adapter(client: client).list_public_events(limit: 1)

    assert_equal [ { "id" => "1" }, { "id" => "2" } ], events
    assert_equal 2, client.calls.size
    assert_equal "/api/v3/public/events", client.calls.last[:uri].path
    assert_equal "limit=1&after=abc", client.calls.last[:uri].query
  end

  test "stops when has_more repeats a next_url" do
    page = {
      "data" => [ { "id" => "1" } ],
      "has_more" => true,
      "next_url" => "https://billetto.dk/api/v3/public/events?after=loop"
    }
    client = Sequence.new([ 200, page.to_json ], [ 200, page.to_json ])

    events = adapter(client: client).list_public_events(limit: 1)

    assert_equal [ { "id" => "1" }, { "id" => "1" } ], events
    assert_equal 2, client.calls.size
  end

  test "refuses to follow next_url to another host" do
    page = {
      "data" => [],
      "has_more" => true,
      "next_url" => "https://evil.example/api/v3/public/events?after=x"
    }
    client = Sequence.new([ 200, page.to_json ])

    assert_raises(Billetto::ResponseError) { adapter(client: client).list_public_events(limit: 1) }
  end

  test "raises ConfigurationError without an api key" do
    client = Recorder.new(status: 200, body: "{}")

    assert_raises(Billetto::ConfigurationError) do
      adapter(client: client, api_key: nil).list_public_events
    end
  end

  test "raises RequestError on a non-success response" do
    client = Recorder.new(status: 401, body: "unauthorized")

    error = assert_raises(Billetto::RequestError) { adapter(client: client).list_public_events }

    assert_match(/401/, error.message)
  end

  test "raises ResponseError on invalid json" do
    client = Recorder.new(status: 200, body: "<html>not json</html>")

    assert_raises(Billetto::ResponseError) { adapter(client: client).list_public_events }
  end

  test "raises ResponseError when the data key is missing" do
    client = Recorder.new(status: 200, body: { "object" => "list" }.to_json)

    assert_raises(Billetto::ResponseError) { adapter(client: client).list_public_events }
  end

  test "wraps transport failures in ConnectionError" do
    client = Recorder.new(status: nil, body: nil, error: Net::ReadTimeout.new)

    assert_raises(Billetto::ConnectionError) { adapter(client: client).list_public_events }
  end
end
