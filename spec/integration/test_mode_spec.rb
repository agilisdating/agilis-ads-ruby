# frozen_string_literal: true

require "zlib"

# Runs against the real API with a Test-mode key (AGILIS_TEST_API_KEY).
# Reads only, plus dry-run calls: nothing is created or charged.
RSpec.describe "Test-mode API", :integration do
  let(:api) { AgilisAds::Client.new(api_key: ENV.fetch("AGILIS_TEST_API_KEY")) }
  let(:offer_image) { File.expand_path("../fixtures/sample-offer.png", __dir__) }

  before do
    key = ENV.fetch("AGILIS_TEST_API_KEY", "")
    raise "AGILIS_TEST_API_KEY is not set" if key.empty?
    raise "Refusing to run the integration tests with a Live key" if key.start_with?("pk_live_")

    WebMock.allow_net_connect!
    allow(Kernel).to receive(:sleep).and_call_original
  end

  after { WebMock.disable_net_connect! }

  # A plain 1280 x 720 PNG, the smallest size an Event image may be.
  def event_image
    width = 1280
    height = 720
    row = "\x00".b + ("\x2a\x6f\xd6".b * width)
    chunk = lambda do |type, data|
      [data.bytesize].pack("N") + type.b + data + [Zlib.crc32(type.b + data)].pack("N")
    end
    png = "\x89PNG\r\n\x1a\n".b
    png << chunk.call("IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC"))
    png << chunk.call("IDAT", Zlib::Deflate.deflate(row * height))
    png << chunk.call("IEND", "".b)
    AgilisAds::Upload.from_bytes(png, filename: "event.png")
  end

  def iso(time)
    time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  it "is in Test mode" do
    expect(api.mode).to eq("test")
  end

  it "reads categories, interests, event categories, currencies and config" do
    expect(api.categories.list.categories).to be_an(Array)
    expect(api.interests.list.interests).to be_an(Array)
    expect(api.event_categories.list.categories).to be_an(Array)
    expect(api.event_currencies.list.currencies).to be_an(Array)
    expect(api.event_config.get.environment.to_s.upcase).to eq("TEST")
  end

  it "lists Offers and Events" do
    expect(api.offers.list(limit: 5).data).to be_an(Array)
    expect(api.events.list(limit: 5).data).to be_an(Array)
  end

  it "estimates an Offer price" do
    estimate = api.offers.estimate_price(start_datetime: iso(Time.now + 86_400),
                                         end_datetime: iso(Time.now + (3 * 86_400)),
                                         location: [51.5074, -0.1278], radius: 10)
    expect(estimate.return_code).to eq("S1")
  end

  it "lists webhook endpoints and webhook events" do
    expect(api.webhook_endpoints.list.data).to be_an(Array)
    expect(api.webhook_events.list(limit: 5).data).to be_an(Array)
  rescue AgilisAds::PermissionError
    skip "This key's role cannot manage webhooks"
  end

  it "dry-runs an Offer create with the sample image" do
    category_id = api.categories.list.categories.first.category_id
    result = api.offers.create(
      { category_id: category_id, title: "SDK dry run", description: "Checks the Ruby SDK. Never created.",
        push_notification_title: "SDK dry run", push_notification_message: "Never sent.",
        url: "https://www.agilis.dating", image: offer_image, location: [51.5074, -0.1278], radius: 10,
        start_datetime: iso(Time.now + 86_400), expiry_datetime: iso(Time.now + (3 * 86_400)),
        payment_method: "B" },
      dry_run: true
    )
    expect(result.return_code).to eq("S1")
    expect(result.dry_run).to be(true)
  end

  it "dry-runs an Event publish with an image" do
    result = api.events.publish(
      { title: "SDK dry run", description: "Checks the Ruby SDK. Never published.", venue_name: "Test venue",
        address: "1 Test Street", city: "London", country_code: "GB", location: [51.5133, -0.13],
        starts_at: iso(Time.now + (30 * 86_400)), ends_at: iso(Time.now + (30 * 86_400) + 7200),
        url: "https://www.agilis.dating", image: event_image, payment_method: "B" },
      dry_run: true
    )
    expect(result.return_code).to eq("S1")
    expect(result.dry_run).to be(true)
  end
end
