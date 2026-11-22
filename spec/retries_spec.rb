# frozen_string_literal: true

RSpec.describe "Retries" do
  let(:api) { client }
  let(:ok) { json_response({ "return_code" => "S1" }) }

  def error_response(status, headers: {})
    json_response({ "return_code" => "E1", "message" => "HTTP #{status}" }, status: status, headers: headers)
  end

  def stub_sequence(method, path, *responses)
    requests = []
    stub_request(method, %r{\A#{Regexp.escape(SpecHelpers::BASE + path)}(\?.*)?\z}).with do |request|
      requests << request
      true
    end.to_return(*responses)
    requests
  end

  it "keeps the same Idempotency-Key on every retry of offers.create" do
    requests = stub_sequence(:post, "/offers", error_response(503), error_response(500), ok)
    api.offers.create(title: "x")
    keys = requests.map { |request| request.headers["Idempotency-Key"] }
    expect(keys.size).to eq(3)
    expect(keys.uniq.size).to eq(1)
  end

  it "keeps the same Idempotency-Key on every retry of events.publish, and uses a new one per call" do
    requests = stub_sequence(:post, "/events", error_response(502), ok, ok)
    api.events.publish(title: "x")
    api.events.publish(title: "y")
    keys = requests.map { |request| request.headers["Idempotency-Key"] }
    expect(keys[0]).to eq(keys[1])
    expect(keys[2]).not_to eq(keys[0])
  end

  [500, 502, 503, 504].each do |status|
    it "retries GET on #{status}" do
      requests = stub_sequence(:get, "/categories", error_response(status), ok)
      expect(api.categories.list.return_code).to eq("S1")
      expect(requests.size).to eq(2)
    end
  end

  it "retries DELETE on 5xx" do
    requests = stub_sequence(:delete, "/offers/1", error_response(503), ok)
    api.offers.delete(1)
    expect(requests.size).to eq(2)
  end

  it "does not retry a POST without an Idempotency-Key on 5xx" do
    requests = stub_sequence(:post, "/offers/1/pause", error_response(503), ok)
    expect { api.offers.pause(1) }.to raise_error(AgilisAds::ApiError)
    expect(requests.size).to eq(1)
  end

  it "does not retry a PATCH on 5xx" do
    requests = stub_sequence(:patch, "/webhook-endpoints/we_1", error_response(500), ok)
    expect { api.webhook_endpoints.update("we_1", status: "enabled") }.to raise_error(AgilisAds::ApiError)
    expect(requests.size).to eq(1)
  end

  it "does not retry other 5xx statuses or 4xx" do
    first = stub_sequence(:get, "/interests", error_response(501), ok)
    expect { api.interests.list }.to raise_error(AgilisAds::ApiError)
    second = stub_sequence(:get, "/categories", error_response(400), ok)
    expect { api.categories.list }.to raise_error(AgilisAds::InvalidRequestError)
    expect([first.size, second.size]).to eq([1, 1])
  end

  it "retries 429 for any method, including PATCH and POST without a key" do
    patches = stub_sequence(:patch, "/webhook-endpoints/we_1", error_response(429), ok)
    posts = stub_sequence(:post, "/offers/1/pause", error_response(429), ok)
    api.webhook_endpoints.update("we_1", status: "enabled")
    api.offers.pause(1)
    expect([patches.size, posts.size]).to eq([2, 2])
  end

  it "retries connection errors and timeouts" do
    requests = []
    stub = stub_request(:get, "#{SpecHelpers::BASE}/categories").with { |request| requests << request }
    stub.to_raise(SocketError).then.to_timeout.then.to_return(ok)
    expect(api.categories.list.return_code).to eq("S1")
    expect(requests.size).to eq(3)
  end

  it "stops after max_retries and raises the last error" do
    requests = stub_sequence(:get, "/categories", error_response(503))
    expect { api.categories.list }.to raise_error(AgilisAds::ApiError) { |error| expect(error.http_status).to eq(503) }
    expect(requests.size).to eq(3)
  end

  it "honours max_retries: 0" do
    requests = stub_sequence(:get, "/categories", error_response(503))
    expect { client(max_retries: 0).categories.list }.to raise_error(AgilisAds::ApiError)
    expect(requests.size).to eq(1)
  end

  it "raises ConnectionError when no response arrives" do
    stub_request(:get, "#{SpecHelpers::BASE}/categories").to_raise(Errno::ECONNREFUSED)
    expect { api.categories.list }.to raise_error(AgilisAds::ConnectionError)
  end

  it "honours Retry-After" do
    stub_sequence(:get, "/categories", error_response(429, headers: { "Retry-After" => "3" }), ok)
    api.categories.list
    expect(Kernel).to have_received(:sleep).with(3.0).once
  end

  it "honours Retry-After on a retried 503" do
    stub_sequence(:get, "/categories", error_response(503, headers: { "Retry-After" => "1.5" }), ok)
    api.categories.list
    expect(Kernel).to have_received(:sleep).with(1.5).once
  end

  def record_waits
    waits = []
    allow(Kernel).to receive(:sleep) { |seconds| waits << seconds }
    waits
  end

  it "waits 0.5 s x 2^attempt without Retry-After" do
    allow(Kernel).to receive(:rand).and_return(0.5)
    waits = record_waits
    stub_sequence(:get, "/categories", error_response(503), error_response(503), ok)
    api.categories.list
    expect(waits).to eq([0.5, 1.0])
  end

  it "applies jitter of up to 25 percent" do
    allow(Kernel).to receive(:rand).and_return(0.0, 0.999999)
    waits = record_waits
    stub_sequence(:get, "/categories", error_response(503), error_response(503), ok)
    api.categories.list
    expect(waits.size).to eq(2)
    expect(waits[0]).to be_within(0.0001).of(0.375)
    expect(waits[1]).to be_within(0.0001).of(1.25)
  end

  it "never waits more than 8 seconds without Retry-After" do
    allow(Kernel).to receive(:rand).and_return(0.999999)
    waits = record_waits
    responses = Array.new(7) { error_response(503) } + [ok]
    stub_sequence(:get, "/categories", *responses)
    client(max_retries: 7).categories.list
    expect(waits.size).to eq(7)
    expect(waits.max).to be <= 8.0
    expect(waits.last).to eq(8.0)
  end
end
