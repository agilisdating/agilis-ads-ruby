# frozen_string_literal: true

RSpec.describe AgilisAds::Client do
  around do |example|
    saved = ENV.fetch("AGILIS_API_KEY", nil)
    ENV.delete("AGILIS_API_KEY")
    example.run
  ensure
    saved.nil? ? ENV.delete("AGILIS_API_KEY") : ENV.store("AGILIS_API_KEY", saved)
  end

  it "takes its mode from a test key" do
    api = described_class.new(api_key: SpecHelpers::TEST_KEY)
    expect(api.mode).to eq("test")
    expect(api).to be_test_mode
    expect(api).not_to be_live_mode
  end

  it "takes its mode from a live key" do
    api = described_class.new(api_key: SpecHelpers::LIVE_KEY)
    expect(api.mode).to eq("live")
    expect(api).to be_live_mode
  end

  it "has no mode for an unrecognised key and then leaves environment out" do
    api = described_class.new(api_key: "something_else")
    expect(api.mode).to be_nil
    requests = capture(:get, "/offers", json_response({ "data" => [], "pagination" => {} }))
    api.offers.list
    expect(query_of(requests.first)).to eq({})
  end

  it "fills environment=LIVE for a live key" do
    requests = capture(:get, "/events", json_response({ "data" => [], "pagination" => {} }))
    described_class.new(api_key: SpecHelpers::LIVE_KEY).events.list
    expect(query_of(requests.first)).to eq({ "environment" => "LIVE" })
  end

  it "reads AGILIS_API_KEY from the environment" do
    ENV["AGILIS_API_KEY"] = SpecHelpers::LIVE_KEY
    expect(described_class.new.mode).to eq("live")
  end

  it "refuses to start without a key" do
    expect { described_class.new }.to raise_error(ArgumentError, /AGILIS_API_KEY/)
  end

  it "has the documented defaults" do
    api = described_class.new(api_key: SpecHelpers::TEST_KEY)
    expect(api.base_url).to eq("https://ads.agilis.dating")
    expect(api.timeout).to eq(60)
    expect(api.max_retries).to eq(2)
  end

  it "sends the standard headers" do
    requests = capture(:get, "/categories")
    described_class.new(api_key: SpecHelpers::TEST_KEY).categories.list
    headers = requests.first.headers
    expect(headers["X-Api-Key"]).to eq(SpecHelpers::TEST_KEY)
    expect(headers["Accept"]).to eq("application/json")
    user_agent = "agilis-ads-ruby/#{AgilisAds::VERSION} (ruby #{RUBY_VERSION}; #{RUBY_PLATFORM})"
    expect(headers["User-Agent"]).to eq(user_agent)
  end

  it "uses a custom base URL" do
    stub = stub_request(:get, "https://example.test/v/categories").to_return(json_response({}))
    described_class.new(api_key: SpecHelpers::TEST_KEY, base_url: "https://example.test/v/").categories.list
    expect(stub).to have_been_requested
  end

  it "uses a custom HTTP client" do
    calls = []
    http_client = lambda do |**request|
      calls << request
      [200, { "X-RateLimit-Remaining" => "59" }, '{"return_code":"S1","categories":[]}']
    end
    result = described_class.new(api_key: SpecHelpers::TEST_KEY, http_client: http_client, timeout: 5).categories.list
    expect(calls.first).to include(method: "GET", url: "https://ads.agilis.dating/categories", body: nil, timeout: 5)
    expect(result.last_response.status).to eq(200)
    expect(result.last_response.rate_limit_remaining).to eq(59)
  end
end
