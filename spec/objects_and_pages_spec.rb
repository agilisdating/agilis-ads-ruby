# frozen_string_literal: true

RSpec.describe "Responses and pagination" do
  let(:api) { client }

  describe AgilisAds::AgilisObject do
    let(:object) do
      values = { "event_id" => 3104, "category" => { "category_id" => 9 }, "tags" => [{ "name" => "a" }],
                 "brand_new_field" => "kept" }
      described_class.new(values)
    end

    it "reads fields as methods and with []" do
      expect(object.event_id).to eq(3104)
      expect(object[:event_id]).to eq(3104)
      expect(object["event_id"]).to eq(3104)
      expect(object.category.category_id).to eq(9)
      expect(object.tags.first.name).to eq("a")
      expect(object.dig(:category, :category_id)).to eq(9)
      expect(object).to respond_to(:brand_new_field)
      expect { object.not_a_field }.to raise_error(NoMethodError)
    end

    it "keeps unknown fields in to_h" do
      expected = { event_id: 3104, category: { category_id: 9 }, tags: [{ name: "a" }], brand_new_field: "kept" }
      expect(object.to_h).to eq(expected)
      expect(JSON.parse(object.to_json)["brand_new_field"]).to eq("kept")
      expect(object.keys).to include(:brand_new_field)
    end
  end

  it "exposes the HTTP status and headers" do
    stub_request(:get, "#{SpecHelpers::BASE}/categories")
      .to_return(json_response({ "categories" => [] }, headers: { "X-RateLimit-Remaining" => "41" }))
    result = api.categories.list
    expect(result.last_response.status).to eq(200)
    expect(result.last_response.header("X-RateLimit-Remaining")).to eq("41")
    expect(result.last_response.rate_limit_remaining).to eq(41)
  end

  describe AgilisAds::Page do
    def page_body(ids, has_more:, next_cursor:)
      pagination = { "limit" => 2, "count" => ids.size, "has_more" => has_more, "next_cursor" => next_cursor }
      json_response({ "data" => ids.map { |id| { "offer_id" => id } }, "pagination" => pagination })
    end

    before do
      stub_request(:get, "#{SpecHelpers::BASE}/offers")
        .with(query: { "limit" => "2", "environment" => "TEST" })
        .to_return(page_body([1, 2], has_more: true, next_cursor: "c2"))
      stub_request(:get, "#{SpecHelpers::BASE}/offers")
        .with(query: { "limit" => "2", "environment" => "TEST", "cursor" => "c2" })
        .to_return(page_body([3, 4], has_more: true, next_cursor: "c3"))
      stub_request(:get, "#{SpecHelpers::BASE}/offers")
        .with(query: { "limit" => "2", "environment" => "TEST", "cursor" => "c3" })
        .to_return(page_body([5], has_more: false, next_cursor: nil))
    end

    it "returns one page from list" do
      page = api.offers.list(limit: 2)
      expect(page.data.map(&:offer_id)).to eq([1, 2])
      expect(page.more?).to be(true)
      expect(page.next_cursor).to eq("c2")
      expect(page.each.map(&:offer_id)).to eq([1, 2])
    end

    it "follows next_cursor until has_more is false" do
      ids = api.offers.list(limit: 2).auto_paging_each.map(&:offer_id)
      expect(ids).to eq([1, 2, 3, 4, 5])
    end

    it "is lazy" do
      first = api.offers.list(limit: 2).auto_paging_each.first(2)
      expect(first.map(&:offer_id)).to eq([1, 2])
      expect(a_request(:get, "#{SpecHelpers::BASE}/offers?cursor=c2&environment=TEST&limit=2")).not_to have_been_made
    end

    it "yields to a block" do
      seen = []
      api.offers.list(limit: 2).auto_paging_each { |offer| seen << offer.offer_id }
      expect(seen).to eq([1, 2, 3, 4, 5])
    end

    it "pages webhook events and events too" do
      first_page = { "data" => [{ "id" => "a" }], "pagination" => { "has_more" => true, "next_cursor" => "n" } }
      last_page = { "data" => [{ "id" => "b" }], "pagination" => {} }
      stub_request(:get, "#{SpecHelpers::BASE}/webhook-events").to_return(json_response(first_page))
      stub_request(:get, "#{SpecHelpers::BASE}/webhook-events")
        .with(query: { "cursor" => "n" })
        .to_return(json_response(last_page))
      expect(api.webhook_events.list.auto_paging_each.map(&:id)).to eq(%w[a b])
    end
  end
end
