# frozen_string_literal: true

RSpec.describe AgilisAds::Webhook do
  vectors = JSON.parse(File.read(File.expand_path("fixtures/webhook-signature-vectors.json", __dir__)))

  describe "shared signature vectors" do
    vectors["cases"].each do |vector|
      it "#{vector['valid'] ? 'accepts' : 'refuses'} #{vector['name']}" do
        verify = lambda do
          described_class.construct_event(vectors["body"], vector["header"], vectors["secret"],
                                          vectors["tolerance_seconds"], now: vectors["now_unix"])
        end
        if vector["valid"]
          event = verify.call
          expect(event.id).to eq("whevt_01JD0S6Q4M8K1Z0X7C2V9B3N5R")
          expect(event.type).to eq("event.published")
          expect(event.data.object.event_id).to eq(3104)
        else
          expect { verify.call }.to raise_error(AgilisAds::SignatureVerificationError) do |error|
            expect(error.reason).to eq(vector["error"].to_sym)
            expect(error.message).not_to include(vectors["secret"])
          end
        end
      end
    end
  end

  def signed_header(body, secret, timestamp)
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.".b + body.b)
    "t=#{timestamp},v1=#{signature}"
  end

  it "verifies the raw bytes of a body read as binary" do
    body = vectors["body"].b
    header = vectors["cases"].find { |vector| vector["name"] == "valid" }["header"]
    event = described_class.construct_event(body, header, vectors["secret"], now: vectors["now_unix"])
    expect(event.data.object.image).to include("…")
  end

  it "uses the current time and a 300-second tolerance by default" do
    body = '{"id":"whevt_1","type":"offer.started","data":{"object":{"offer_id":1}}}'
    now = Time.now.to_i
    expect(described_class.construct_event(body, signed_header(body, "whsec_a", now - 200), "whsec_a").id)
      .to eq("whevt_1")
    expect { described_class.construct_event(body, signed_header(body, "whsec_a", now - 400), "whsec_a") }
      .to raise_error(AgilisAds::SignatureVerificationError)
  end

  it "accepts a custom tolerance" do
    body = '{"id":"whevt_1"}'
    header = signed_header(body, "whsec_a", 1000)
    expect(described_class.construct_event(body, header, "whsec_a", 600, now: 1500).id).to eq("whevt_1")
    expect { described_class.construct_event(body, header, "whsec_a", 60, now: 1500) }
      .to raise_error(AgilisAds::SignatureVerificationError) { |error| expect(error.reason).to eq(:timestamp) }
  end

  it "refuses a nil header" do
    expect { described_class.construct_event("{}", nil, "whsec_a") }
      .to raise_error(AgilisAds::SignatureVerificationError) { |error| expect(error.reason).to eq(:header) }
  end

  it "refuses a signed body that is not a JSON object" do
    header = signed_header("not json", "whsec_a", 1000)
    expect { described_class.construct_event("not json", header, "whsec_a", now: 1000) }
      .to raise_error(AgilisAds::SignatureVerificationError) { |error| expect(error.reason).to eq(:payload) }
  end

  it "requires a secret" do
    expect { described_class.construct_event("{}", "t=1,v1=a", "") }.to raise_error(ArgumentError)
  end

  it "is available as client.webhooks.construct_event" do
    valid = vectors["cases"].first
    event = client.webhooks.construct_event(vectors["body"], valid["header"], vectors["secret"],
                                            now: vectors["now_unix"])
    expect(event.type).to eq("event.published")
  end
end
