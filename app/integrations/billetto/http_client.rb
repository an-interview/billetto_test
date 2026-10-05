require "net/http"

module Billetto
  # Minimal GET transport so the adapter can be tested without network access.
  class HttpClient
    def call(uri:, headers:, open_timeout:, read_timeout:)
      request = Net::HTTP::Get.new(uri)
      headers.each { |name, value| request[name] = value }

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: open_timeout,
        read_timeout: read_timeout
      ) { |http| http.request(request) }

      [ response.code.to_i, response.body ]
    end
  end
end
