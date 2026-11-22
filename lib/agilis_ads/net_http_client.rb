# frozen_string_literal: true

module AgilisAds
  # The default HTTP client, built on Net::HTTP.
  #
  # Any object with the same `call` method can be passed to the client as
  # `http_client:`. It returns `[status, headers, body]`. On a network failure
  # it raises AgilisAds::ConnectionError or one of Ruby's own network errors
  # (timeouts, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError).
  class NetHttpClient
    REQUEST_CLASSES = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PATCH" => Net::HTTP::Patch,
      "PUT" => Net::HTTP::Put,
      "DELETE" => Net::HTTP::Delete
    }.freeze

    def call(method:, url:, headers:, body:, timeout:)
      uri = URI(url)
      request = REQUEST_CLASSES.fetch(method).new(uri)
      headers.each { |name, value| request[name] = value }
      request.body = body if body

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout
      response = http.start { |connection| connection.request(request) }

      response_headers = {}
      response.each_header { |name, value| response_headers[name] = value }
      [response.code.to_i, response_headers, response.body.to_s]
    end
  end
end
