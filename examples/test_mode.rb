# frozen_string_literal: true

# A short Test-mode tour. Run with:
#   AGILIS_API_KEY=pk_test_... ruby -Ilib examples/test_mode.rb
require "agilis_ads"

client = AgilisAds::Client.new
abort "Use a Test-mode key (pk_test_...) for this example." unless client.test_mode?

begin
  client.categories.list.categories.first(5).each do |category|
    puts "Category #{category.category_id}: #{category.category_name}"
  end

  estimate = client.offers.estimate_price(
    start_datetime: Time.now + 86_400,
    end_datetime: Time.now + (3 * 86_400),
    location: [51.5074, -0.1278],
    radius: 10
  )
  puts "Estimated cost: #{estimate.estimated_cost} #{estimate.currency}"

  client.offers.list(limit: 20).auto_paging_each do |offer|
    puts "Offer #{offer.offer_id}: #{offer.title}"
  end

  # A dry run checks everything and reports the price, but creates nothing.
  image = File.expand_path("../spec/fixtures/sample-offer.png", __dir__)
  check = client.offers.create(
    {
      category_id: client.categories.list.categories.first.category_id,
      title: "Summer Sale",
      description: "Twenty percent off everything in August.",
      push_notification_title: "Summer Sale",
      push_notification_message: "Twenty percent off, this week only.",
      url: "https://www.example.com/summer-sale",
      image: image,
      location: [51.5074, -0.1278],
      radius: 10,
      gender: %w[Male Female],
      start_datetime: Time.now + 86_400,
      expiry_datetime: Time.now + (7 * 86_400),
      payment_method: "B"
    },
    dry_run: true
  )
  puts "Dry run: #{check.to_h}"
rescue AgilisAds::AgilisError => e
  warn "#{e.class}: #{e.message} (HTTP #{e.http_status}, #{e.return_code})"
end
