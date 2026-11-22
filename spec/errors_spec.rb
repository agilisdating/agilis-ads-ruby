# frozen_string_literal: true

RSpec.describe "Errors" do
  let(:api) { client(max_retries: 0) }

  {
    400 => AgilisAds::InvalidRequestError,
    401 => AgilisAds::AuthenticationError,
    403 => AgilisAds::PermissionError,
    404 => AgilisAds::NotFoundError,
    409 => AgilisAds::ConflictError,
    422 => AgilisAds::InvalidRequestError,
    429 => AgilisAds::RateLimitError,
    500 => AgilisAds::ApiError,
    503 => AgilisAds::ApiError,
    418 => AgilisAds::ApiError
  }.each do |status, error_class|
    it "maps HTTP #{status} to #{error_class.name.split('::').last}" do
      body = { "return_code" => "E1", "message" => "Refused", "status" => "Error" }
      stub_request(:get, "#{SpecHelpers::BASE}/categories")
        .to_return(json_response(body, status: status, headers: { "X-RateLimit-Remaining" => "7" }))
      expect { api.categories.list }.to raise_error(error_class) do |error|
        expect(error).to be_a(AgilisAds::AgilisError)
        expect(error.http_status).to eq(status)
        expect(error.return_code).to eq("E1")
        expect(error.message).to eq("Refused")
        expect(error.body).to eq(body)
        expect(error.headers["x-ratelimit-remaining"]).to eq("7")
      end
    end
  end

  it "gives RateLimitError the Retry-After seconds" do
    stub_request(:get, "#{SpecHelpers::BASE}/categories")
      .to_return(json_response({ "message" => "Slow down" }, status: 429, headers: { "Retry-After" => "12" }))
    expect { api.categories.list }.to raise_error(AgilisAds::RateLimitError) do |error|
      expect(error.retry_after).to eq(12.0)
    end
  end

  it "raises InvalidRequestError for HTTP 200 with an E return_code" do
    stub_request(:post, "#{SpecHelpers::BASE}/offers")
      .to_return(json_response({ "return_code" => "E3", "message" => "Insufficient balance" }))
    expect { api.offers.create(title: "x") }.to raise_error(AgilisAds::InvalidRequestError) do |error|
      expect(error.http_status).to eq(200)
      expect(error.return_code).to eq("E3")
      expect(error.message).to eq("Insufficient balance")
    end
  end

  it "treats S1 and S2 as success" do
    stub_request(:post, "#{SpecHelpers::BASE}/offers/1/resume").to_return(json_response({ "return_code" => "S2" }))
    stub_request(:post, "#{SpecHelpers::BASE}/offers/1/pause").to_return(json_response({ "return_code" => "S1" }))
    expect(api.offers.resume(1).return_code).to eq("S2")
    expect(api.offers.pause(1).return_code).to eq("S1")
  end

  it "handles a body that is not JSON" do
    stub_request(:get, "#{SpecHelpers::BASE}/categories").to_return(status: 502, body: "<html>Bad gateway</html>")
    expect { api.categories.list }.to raise_error(AgilisAds::ApiError) do |error|
      expect(error.message).to eq("HTTP 502")
      expect(error.body).to eq("<html>Bad gateway</html>")
    end
  end

  describe "the API key" do
    it "is never in an error message, even when the server echoes it" do
      stub_request(:get, "#{SpecHelpers::BASE}/categories")
        .to_return(json_response({ "message" => "Bad key #{SpecHelpers::TEST_KEY}" }, status: 401))
      expect { api.categories.list }.to raise_error(AgilisAds::AuthenticationError) do |error|
        expect(error.message).not_to include(SpecHelpers::TEST_KEY)
        expect(error.full_message).not_to include(SpecHelpers::TEST_KEY)
        expect(error.inspect).not_to include(SpecHelpers::TEST_KEY)
      end
    end

    it "is never in a connection error message" do
      stub_request(:get, "#{SpecHelpers::BASE}/categories")
        .to_raise(SocketError.new("failed with #{SpecHelpers::TEST_KEY}"))
      expect { api.categories.list }.to raise_error(AgilisAds::ConnectionError) do |error|
        expect(error.message).not_to include(SpecHelpers::TEST_KEY)
        expect(error.message).to include("[redacted]")
      end
    end

    it "is never in the URL and is sent only as x-api-key" do
      requests = capture(:get, "/offers", json_response({ "data" => [], "pagination" => {} }))
      api.offers.list
      expect(requests.first.uri.to_s).not_to include(SpecHelpers::TEST_KEY)
      expect(requests.first.headers["X-Api-Key"]).to eq(SpecHelpers::TEST_KEY)
      expect(requests.first.headers).not_to have_key("Authorization")
    end

    it "is not shown by inspect on the client or its resources" do
      expect(api.inspect).not_to include(SpecHelpers::TEST_KEY)
      expect(api.offers.inspect).not_to include(SpecHelpers::TEST_KEY)
    end
  end
end
