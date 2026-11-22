# frozen_string_literal: true

require "agilis_ads"
require "webmock/rspec"

module SpecHelpers
  TEST_KEY = "pk_test_0123456789abcdefSECRET"
  LIVE_KEY = "pk_live_0123456789abcdefSECRET"
  BASE = "https://ads.agilis.dating"

  def client(**options)
    AgilisAds::Client.new(api_key: TEST_KEY, **options)
  end

  def json_response(body, status: 200, headers: {})
    { status: status, body: JSON.generate(body), headers: { "Content-Type" => "application/json" }.merge(headers) }
  end

  # Stubs a request and returns an array that collects every matching request.
  def capture(method, path, response = json_response({ "return_code" => "S1" }))
    requests = []
    stub_request(method, %r{\A#{Regexp.escape(BASE + path)}(\?.*)?\z}).with do |request|
      requests << request
      true
    end.to_return(response)
    requests
  end

  def query_of(request)
    URI.decode_www_form(request.uri.query.to_s).to_h
  end

  # Parses a multipart body into [{ name:, filename:, content_type:, value: }].
  def multipart_parts(request)
    boundary = request.headers["Content-Type"][/boundary=(.+)\z/, 1]
    raw = request.body.to_s.b
    raw.split("--#{boundary}".b).filter_map do |chunk|
      next if chunk.empty? || chunk.start_with?("--")

      head, value = chunk.sub(/\A\r\n/n, "").split("\r\n\r\n".b, 2)
      {
        name: head[/name="([^"]*)"/, 1],
        filename: head[/filename="([^"]*)"/, 1],
        content_type: head[/Content-Type: (.+)/, 1]&.strip,
        value: value.delete_suffix("\r\n".b)
      }
    end
  end

  def part_values(request, name)
    multipart_parts(request).select { |part| part[:name] == name }.map { |part| part[:value] }
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
  config.disable_monkey_patching!
  config.order = :random
  config.filter_run_excluding integration: true unless ENV["AGILIS_INTEGRATION"] == "1"

  config.before do
    allow(Kernel).to receive(:sleep)
  end
end
