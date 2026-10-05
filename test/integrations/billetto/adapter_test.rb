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
