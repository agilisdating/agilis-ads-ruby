# frozen_string_literal: true

RSpec.describe "Operations" do
  let(:api) { client }
  let(:image_path) { File.expand_path("fixtures/sample-offer.png", __dir__) }

  def expect_json_body(request, expected)
    expect(request.headers["Content-Type"]).to eq("application/json")
    expect(JSON.parse(request.body)).to eq(expected)
  end

  describe "simple lists" do
    {
      categories: "/categories",
      interests: "/interests",
      event_categories: "/event-categories",
      event_currencies: "/event-currencies"
    }.each do |resource, path|
      it "#{resource}.list sends GET #{path}" do
        requests = capture(:get, path, json_response({ "return_code" => "S1", "items" => [1] }))
        result = api.public_send(resource).list
        expect(requests.size).to eq(1)
        expect(requests.first.uri.query).to be_nil
        expect(result.items).to eq([1])
      end
    end

    it "event_config.get sends GET /event-config" do
      requests = capture(:get, "/event-config", json_response({ "listing_fee" => 10 }))
      expect(api.event_config.get.listing_fee).to eq(10)
      expect(requests.size).to eq(1)
    end
  end

  describe "offers" do
    it "estimate_price sends JSON and fills environment from the key" do
      requests = capture(:post, "/offers/price-estimate")
      api.offers.estimate_price(start_datetime: "2027-07-10T08:00:00Z", end_datetime: "2027-07-12T20:30:00Z",
                                location: [51.5074, -0.1278], radius: 10, gender: ["Male"], interests: [3, 7])
      expected = {
        "start_datetime" => "2027-07-10T08:00:00Z", "end_datetime" => "2027-07-12T20:30:00Z",
        "location" => [51.5074, -0.1278], "radius" => 10, "gender" => ["Male"],
        "interests" => [3, 7], "environment" => "TEST"
      }
      expect_json_body(requests.first, expected)
    end

    it "estimate_price keeps an environment the caller gave" do
      requests = capture(:post, "/offers/price-estimate")
      api.offers.estimate_price({ "environment" => "LIVE", radius: 5 })
      expect(JSON.parse(requests.first.body)).to eq({ "environment" => "LIVE", "radius" => 5 })
    end

    it "create sends multipart with repeated array parts, the image and an Idempotency-Key" do
      requests = capture(:post, "/offers", json_response({ "return_code" => "S1", "offer_id" => 45 }))
      offer = api.offers.create(
        category_id: 1, title: "Summer Sale", description: "Twenty percent off", url: "https://example.com",
        push_notification_title: "Sale", push_notification_message: "Now on",
        location: [51.5074, -0.1278], radius: 10, gender: %w[Male Female], interests: [3, 7],
        start_datetime: Time.utc(2027, 8, 1, 9), expiry_datetime: "2027-08-31T23:59:00Z",
        payment_method: "B", image: image_path
      )
      request = requests.first
      expect(offer.offer_id).to eq(45)
      expect(request.uri.query).to be_nil
      expect(request.headers["Idempotency-Key"]).to match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/)
      expect(request.headers["Content-Type"]).to start_with("multipart/form-data; boundary=")
      expect(part_values(request, "location[]")).to eq(%w[51.5074 -0.1278])
      expect(part_values(request, "gender[]")).to eq(%w[Male Female])
      expect(part_values(request, "interests[]")).to eq(%w[3 7])
      expect(part_values(request, "category_id")).to eq(["1"])
      expect(part_values(request, "start_datetime")).to eq(["2027-08-01T09:00:00Z"])
      expect(part_values(request, "environment")).to eq(["TEST"])
      image = multipart_parts(request).find { |part| part[:name] == "image" }
      expect(image[:filename]).to eq("sample-offer.png")
      expect(image[:content_type]).to eq("image/png")
      expect(image[:value]).to eq(File.binread(image_path))
    end

    it "create uses the caller's Idempotency-Key and dry_run" do
      requests = capture(:post, "/offers")
      api.offers.create({ title: "x" }, dry_run: true, idempotency_key: "my-key")
      expect(requests.first.headers["Idempotency-Key"]).to eq("my-key")
      expect(query_of(requests.first)).to eq({ "dry_run" => "true" })
    end

    it "create accepts bytes and IO uploads" do
      requests = capture(:post, "/offers")
      api.offers.create(image: AgilisAds::Upload.from_bytes("\x89PNG\x00\xFF".b, filename: "a.JPG"))
      File.open(image_path, "rb") { |file| api.offers.create(image: file) }
      first, second = requests.map { |request| multipart_parts(request).find { |part| part[:name] == "image" } }
      expect(first).to include(filename: "a.JPG", content_type: "image/jpeg", value: "\x89PNG\x00\xFF".b)
      expect(second).to include(filename: "sample-offer.png", content_type: "image/png")
    end

    it "list sends the query with environment and returns a page" do
      requests = capture(:get, "/offers", json_response({ "data" => [{ "offer_id" => 1 }],
                                                          "pagination" => { "has_more" => false } }))
      page = api.offers.list(limit: 50, offer_status: "active")
      expect(query_of(requests.first)).to eq({ "limit" => "50", "offer_status" => "active", "environment" => "TEST" })
      expect(page.data.map(&:offer_id)).to eq([1])
    end

    { pause: "/offers/45/pause", resume: "/offers/45/resume" }.each do |method, path|
      it "#{method} sends POST #{path}" do
        requests = capture(:post, path, json_response({ "return_code" => "S2" }))
        expect(api.offers.public_send(method, 45).return_code).to eq("S2")
        expect(requests.first.headers["Content-Length"]).to eq("0")
        expect(requests.first.headers).not_to have_key("Idempotency-Key")
      end
    end

    it "analytics sends GET with interval" do
      requests = capture(:get, "/offers/45/analytics")
      api.offers.analytics(45, interval: "30d")
      expect(query_of(requests.first)).to eq({ "interval" => "30d" })
    end

    it "delete sends DELETE, with dry_run when asked" do
      requests = capture(:delete, "/offers/45")
      api.offers.delete(45)
      api.offers.delete(45, dry_run: true)
      expect(requests.map { |request| query_of(request) }).to eq([{}, { "dry_run" => "true" }])
    end
  end

  describe "events" do
    it "preview sends multipart with crop fields and environment" do
      requests = capture(:post, "/events/preview")
      api.events.preview(title: "Salsa", image: image_path, crop: { x: 0, y: 10, w: 1280 })
      request = requests.first
      expect(part_values(request, "crop[x]")).to eq(["0"])
      expect(part_values(request, "crop[y]")).to eq(["10"])
      expect(part_values(request, "crop[w]")).to eq(["1280"])
      expect(part_values(request, "environment")).to eq(["TEST"])
      expect(request.headers).not_to have_key("Idempotency-Key")
    end

    it "accepts literal crop[x] names" do
      requests = capture(:post, "/events/preview")
      api.events.preview({ "crop[x]" => 5 })
      expect(part_values(requests.first, "crop[x]")).to eq(["5"])
    end

    it "publish sends multipart, an Idempotency-Key and dry_run" do
      requests = capture(:post, "/events", json_response({ "return_code" => "S1", "event_id" => 3104 }))
      api.events.publish({ title: "Salsa", location: [51.5133, -0.13], payment_method: "B" }, dry_run: true)
      request = requests.first
      expect(query_of(request)).to eq({ "dry_run" => "true" })
      expect(request.headers["Idempotency-Key"]).not_to be_empty
      expect(part_values(request, "location[]")).to eq(%w[51.5133 -0.13])
      expect(part_values(request, "environment")).to eq(["TEST"])
    end

    it "list sends the query with environment" do
      requests = capture(:get, "/events", json_response({ "data" => [], "pagination" => {} }))
      api.events.list(event_status: "Scheduled", owner_user_id: 41)
      expect(query_of(requests.first)).to eq({ "event_status" => "Scheduled", "owner_user_id" => "41",
                                               "environment" => "TEST" })
    end

    it "get sends GET /events/{id}" do
      requests = capture(:get, "/events/3104", json_response({ "event_id" => 3104, "title" => "Salsa" }))
      expect(api.events.get(3104).title).to eq("Salsa")
      expect(requests.size).to eq(1)
    end

    it "edit without a file sends PATCH multipart" do
      requests = capture(:patch, "/events/3104")
      api.events.edit(3104, title: "New title")
      expect(part_values(requests.first, "title")).to eq(["New title"])
      expect(requests.first.headers).not_to have_key("X-Http-Method-Override")
    end

    it "edit with a file sends POST with X-HTTP-Method-Override: PATCH" do
      requests = capture(:post, "/events/3104")
      api.events.edit(3104, image: image_path, crop: { x: 1, y: 2, w: 1280 })
      request = requests.first
      expect(request.headers["X-Http-Method-Override"]).to eq("PATCH")
      expect(multipart_parts(request).map { |part| part[:name] }).to eq(["image", "crop[x]", "crop[y]", "crop[w]"])
      expect(part_values(request, "environment")).to be_empty
    end

    it "delete sends DELETE with dry_run" do
      requests = capture(:delete, "/events/3104")
      api.events.delete(3104, dry_run: true)
      expect(query_of(requests.first)).to eq({ "dry_run" => "true" })
    end

    it "reschedule sends JSON" do
      requests = capture(:post, "/events/3104/reschedule")
      api.events.reschedule(3104, starts_at: "2027-10-17T18:30:00Z", ends_at: "2027-10-17T23:00:00Z")
      expect_json_body(requests.first, { "starts_at" => "2027-10-17T18:30:00Z", "ends_at" => "2027-10-17T23:00:00Z" })
    end

    it "cancel sends POST, with dry_run when asked" do
      requests = capture(:post, "/events/3104/cancel")
      api.events.cancel(3104)
      api.events.cancel(3104, dry_run: true)
      expect(requests.map { |request| query_of(request) }).to eq([{}, { "dry_run" => "true" }])
    end

    it "analytics sends GET with interval" do
      requests = capture(:get, "/events/3104/analytics")
      api.events.analytics(3104, { interval: "7d" })
      expect(query_of(requests.first)).to eq({ "interval" => "7d" })
    end
  end

  describe "webhook endpoints" do
    let(:id) { "we_01JD2X4Q7N8P9R0S1T2V3W4X5Y" }

    it "list sends GET /webhook-endpoints" do
      requests = capture(:get, "/webhook-endpoints", json_response({ "return_code" => "S1", "data" => [] }))
      expect(api.webhook_endpoints.list.data).to eq([])
      expect(requests.size).to eq(1)
    end

    it "create sends JSON" do
      requests = capture(:post, "/webhook-endpoints", json_response({ "return_code" => "S1", "secret" => "whsec_x" }))
      endpoint = api.webhook_endpoints.create(url: "https://example.com/hook", enabled_events: ["event.published"])
      expect(endpoint.secret).to eq("whsec_x")
      expect_json_body(requests.first, { "url" => "https://example.com/hook", "enabled_events" => ["event.published"] })
      expect(requests.first.headers).not_to have_key("Idempotency-Key")
    end

    it "get, update and delete use the endpoint path" do
      gets = capture(:get, "/webhook-endpoints/#{id}")
      patches = capture(:patch, "/webhook-endpoints/#{id}")
      deletes = capture(:delete, "/webhook-endpoints/#{id}")
      api.webhook_endpoints.get(id)
      api.webhook_endpoints.update(id, status: "disabled")
      api.webhook_endpoints.delete(id)
      expect([gets.size, patches.size, deletes.size]).to eq([1, 1, 1])
      expect_json_body(patches.first, { "status" => "disabled" })
    end

    it "roll_secret and send_test send JSON" do
      rolls = capture(:post, "/webhook-endpoints/#{id}/roll-secret")
      tests = capture(:post, "/webhook-endpoints/#{id}/test")
      api.webhook_endpoints.roll_secret(id, expires_in: 3600)
      api.webhook_endpoints.send_test(id)
      expect_json_body(rolls.first, { "expires_in" => 3600 })
      expect_json_body(tests.first, {})
    end

    it "escapes path segments" do
      requests = capture(:get, "/webhook-endpoints/a%2Fb%20c")
      api.webhook_endpoints.get("a/b c")
      expect(requests.size).to eq(1)
    end

    it "refuses an empty id" do
      expect { api.webhook_endpoints.get("") }.to raise_error(ArgumentError)
    end
  end

  describe "webhook events" do
    let(:id) { "whevt_01JD2Y8B3C4D5E6F7G8H9J0K1M" }

    it "list sends the query without environment" do
      requests = capture(:get, "/webhook-events", json_response({ "data" => [], "pagination" => {} }))
      api.webhook_events.list(delivery_success: false, type: "event.published", limit: 20)
      expect(query_of(requests.first)).to eq({ "delivery_success" => "false", "type" => "event.published",
                                               "limit" => "20" })
    end

    it "get and resend use the event path" do
      gets = capture(:get, "/webhook-events/#{id}")
      resends = capture(:post, "/webhook-events/#{id}/resend")
      api.webhook_events.get(id)
      api.webhook_events.resend(id, endpoint_id: "we_1")
      expect(gets.size).to eq(1)
      expect_json_body(resends.first, { "endpoint_id" => "we_1" })
    end
  end
end
