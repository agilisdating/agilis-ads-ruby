# Agilis Advertising API for Ruby

The official Ruby library for the [Agilis Advertising REST API](https://www.agilis.dating/api-doc): create and manage Offers and Events, read their results, manage webhook endpoints, and verify the webhooks Agilis sends you.

- Ruby 3.2 or later
- No runtime dependencies: it uses Ruby's own `net/http`, `json` and `openssl`

## Install

```ruby
# Gemfile
gem "agilis-ads"
```

or `gem install agilis-ads`.

## Quick start (Test mode)

Create a Test-mode key (`pk_test_...`) in the Ad Portal and keep it in an environment variable, never in code.

```ruby
require "agilis_ads"

client = AgilisAds::Client.new(api_key: ENV.fetch("AGILIS_API_KEY"))
client.mode # => "test"

client.categories.list.categories.each do |category|
  puts "#{category.category_id}: #{category.category_name}"
end

estimate = client.offers.estimate_price(
  start_datetime: "2027-07-10T08:00:00Z",
  end_datetime: "2027-07-12T20:30:00Z",
  location: [51.5074, -0.1278],
  radius: 10
)
puts estimate.estimated_cost

offer = client.offers.create(
  category_id: 1,
  title: "Summer Sale",
  description: "Twenty percent off everything in August.",
  push_notification_title: "Summer Sale",
  push_notification_message: "Twenty percent off, this week only.",
  url: "https://www.example.com/summer-sale",
  image: "offer.png",
  location: [51.5074, -0.1278],
  radius: 10,
  gender: %w[Male Female],
  interests: [3, 7],
  start_datetime: "2027-08-01T09:00:00Z",
  expiry_datetime: "2027-08-31T23:59:00Z",
  payment_method: "B"
)
puts offer.offer_id
```

A Test key works with TEST data only: members never see it and nothing is charged. With a Live key (`pk_live_...`) changes are real. `client.mode` is `"test"` or `"live"` (also `client.test_mode?` and `client.live_mode?`), so a script can refuse to run against Live.

More: [`examples/test_mode.rb`](examples/test_mode.rb) and [`examples/webhook_receiver.rb`](examples/webhook_receiver.rb).

## Client options

```ruby
AgilisAds::Client.new(
  api_key: "pk_test_...",                   # default: ENV["AGILIS_API_KEY"]
  base_url: "https://ads.agilis.dating",    # default
  timeout: 60,                              # seconds per attempt, default 60
  max_retries: 2,                           # default 2
  http_client: AgilisAds::NetHttpClient.new # default
)
```

`http_client` can be any object with `call(method:, url:, headers:, body:, timeout:)` that returns `[status, headers, body]`.

The key is sent only in the `x-api-key` header. It is never logged, never put in a URL and never included in an error message.

## Resources and methods

Each method takes path parameters as arguments and everything else as keyword arguments (or one hash), using the API's own field names. Operations that take `environment` fill it in from your key when you leave it out.

| Method | HTTP |
|---|---|
| `client.categories.list` | `GET /categories` |
| `client.interests.list` | `GET /interests` |
| `client.offers.estimate_price(**params)` | `POST /offers/price-estimate` |
| `client.offers.create(**params, dry_run: false, idempotency_key: nil)` | `POST /offers` |
| `client.offers.list(**params)` | `GET /offers` |
| `client.offers.pause(offer_id)` | `POST /offers/{offer_id}/pause` |
| `client.offers.resume(offer_id)` | `POST /offers/{offer_id}/resume` |
| `client.offers.analytics(offer_id, interval: "30d")` | `GET /offers/{offer_id}/analytics` |
| `client.offers.delete(offer_id, dry_run: false)` | `DELETE /offers/{offer_id}` |
| `client.event_categories.list` | `GET /event-categories` |
| `client.event_currencies.list` | `GET /event-currencies` |
| `client.event_config.get` | `GET /event-config` |
| `client.events.preview(**params)` | `POST /events/preview` |
| `client.events.publish(**params, dry_run: false, idempotency_key: nil)` | `POST /events` |
| `client.events.list(**params)` | `GET /events` |
| `client.events.get(event_id)` | `GET /events/{event_id}` |
| `client.events.edit(event_id, **params)` | `PATCH /events/{event_id}` |
| `client.events.delete(event_id, dry_run: false)` | `DELETE /events/{event_id}` |
| `client.events.reschedule(event_id, starts_at:, ends_at:)` | `POST /events/{event_id}/reschedule` |
| `client.events.cancel(event_id, dry_run: false)` | `POST /events/{event_id}/cancel` |
| `client.events.analytics(event_id, interval: "30d")` | `GET /events/{event_id}/analytics` |
| `client.webhook_endpoints.list` | `GET /webhook-endpoints` |
| `client.webhook_endpoints.create(url:, enabled_events:, description: nil)` | `POST /webhook-endpoints` |
| `client.webhook_endpoints.get(endpoint_id)` | `GET /webhook-endpoints/{endpoint_id}` |
| `client.webhook_endpoints.update(endpoint_id, **params)` | `PATCH /webhook-endpoints/{endpoint_id}` |
| `client.webhook_endpoints.delete(endpoint_id)` | `DELETE /webhook-endpoints/{endpoint_id}` |
| `client.webhook_endpoints.roll_secret(endpoint_id, expires_in: nil)` | `POST /webhook-endpoints/{endpoint_id}/roll-secret` |
| `client.webhook_endpoints.send_test(endpoint_id, type: nil)` | `POST /webhook-endpoints/{endpoint_id}/test` |
| `client.webhook_events.list(**params)` | `GET /webhook-events` |
| `client.webhook_events.get(webhook_event_id)` | `GET /webhook-events/{webhook_event_id}` |
| `client.webhook_events.resend(webhook_event_id, endpoint_id: nil)` | `POST /webhook-events/{webhook_event_id}/resend` |
| `AgilisAds::Webhook.construct_event(raw_body, header, secret)` | verifies a received webhook |

`dry_run: true` sends `dry_run=true`: the API checks everything and reports the price, but creates, deletes or cancels nothing.

### Images and multipart fields

`offers.create`, `events.preview`, `events.publish` and `events.edit` are sent as `multipart/form-data`. Arrays become repeated `[]` parts (`location[]`, `gender[]`, `interests[]`), and `crop: { x: 0, y: 120, w: 1920 }` becomes `crop[x]`, `crop[y]` and `crop[w]`.

`image:` takes a file path, an open file, or an `AgilisAds::Upload`:

```ruby
image: "offer.png"
image: File.open("offer.png", "rb")
image: AgilisAds::Upload.from_bytes(png_bytes, filename: "offer.png")
```

The content type is detected from the file name. `events.edit` with a new image is sent as `POST` with `X-HTTP-Method-Override: PATCH`, as the API requires.

`Time` values are sent as ISO 8601 in UTC (`2027-08-01T09:00:00Z`).

### Responses

Every method returns an `AgilisAds::AgilisObject`. Fields are methods (`offer.offer_id`) or `offer[:offer_id]`; nested objects work the same way. Fields this version does not know about are kept, and `to_h` returns them all as a plain hash.

The HTTP status and headers are on `last_response`:

```ruby
categories = client.categories.list
categories.last_response.status               # => 200
categories.last_response.rate_limit_remaining # X-RateLimit-Remaining
categories.last_response.header("X-RateLimit-Limit")
```

## Pagination

`offers.list`, `events.list` and `webhook_events.list` return one page (`AgilisAds::Page`): `page.data`, `page.more?`, `page.next_cursor` and `page.next_page`. To go through every item, `auto_paging_each` follows `next_cursor` until `has_more` is false, fetching pages only as they are needed:

```ruby
client.offers.list(limit: 100, offer_status: "active").auto_paging_each do |offer|
  puts offer.title
end

recent = client.events.list(limit: 50).auto_paging_each.first(10) # an Enumerator without a block
```

## Idempotency and retries

`offers.create` and `events.publish` always send an `Idempotency-Key`: yours if you pass `idempotency_key:`, otherwise a random UUID created once for the call and reused on every retry, so a retried request never creates a second Offer or Event or charges twice.

Up to `max_retries` (default 2) retries are made for:

- connection errors and timeouts;
- HTTP 429;
- HTTP 500, 502, 503 and 504 on `GET` and `DELETE`, and on `POST`s that carry an Idempotency-Key.

Other `POST` and `PATCH` requests are not retried on a 5xx, because the change may already have happened. The wait is the `Retry-After` header when there is one; otherwise 0.5 s × 2^attempt with ±25% jitter, at most 8 seconds.

## Errors

Every error is an `AgilisAds::AgilisError` with `http_status`, `return_code`, `message`, `body` (the parsed response) and `headers`.

| Class | When |
|---|---|
| `AgilisAds::AuthenticationError` | 401 |
| `AgilisAds::PermissionError` | 403 |
| `AgilisAds::NotFoundError` | 404 |
| `AgilisAds::ConflictError` | 409 |
| `AgilisAds::InvalidRequestError` | 400, 422, or HTTP 200 with a `return_code` starting with `E` (for example `E3`, balance too low) |
| `AgilisAds::RateLimitError` | 429; `retry_after` holds the seconds to wait |
| `AgilisAds::ApiError` | 5xx and any other status |
| `AgilisAds::ConnectionError` | no response |
| `AgilisAds::SignatureVerificationError` | `construct_event` could not verify a webhook |

`S1` and `S2` are both success.

```ruby
begin
  client.offers.create(params)
rescue AgilisAds::InvalidRequestError => e
  warn "Refused: #{e.return_code} #{e.message}"
rescue AgilisAds::RateLimitError => e
  sleep e.retry_after || 1
  retry
end
```

## Webhooks

Agilis signs every webhook with the `Agilis-Signature` header. `construct_event` checks it against your endpoint's secret, in constant time, and returns the parsed event. It accepts any matching `v1` signature (after a secret roll there are two) and refuses a timestamp more than 300 seconds from now (pass a different `tolerance` as the fourth argument).

Always pass the body exactly as received, not re-encoded JSON.

```ruby
# Sinatra
post "/agilis/webhooks" do
  event = AgilisAds::Webhook.construct_event(
    request.body.read,
    request.env["HTTP_AGILIS_SIGNATURE"],
    ENV.fetch("AGILIS_WEBHOOK_SECRET")
  )
  case event.type
  when "offer.started" then puts "Offer #{event.data.object.offer_id} started"
  when "event.published" then puts "Event #{event.data.object.event_id} published"
  end
  status 200
rescue AgilisAds::SignatureVerificationError
  halt 400
end
```

In Rails, read the body with `request.raw_post` and the header with `request.headers["Agilis-Signature"]`. `SignatureVerificationError#reason` is `:header`, `:timestamp`, `:signature` or `:payload`.

Answer with a 2xx within 10 seconds and do the work afterwards. Events can arrive more than once and out of order: use `event.id` to ignore repeats and `event.created` to order them.

## Links

- API reference: https://www.agilis.dating/api-doc
- OpenAPI: https://www.agilis.dating/openapi.json
- AsyncAPI (webhooks): https://www.agilis.dating/asyncapi.json
- API examples and MCP server: https://github.com/agilisdating/agilis-ads-api

## Licence

MIT. See [LICENSE](LICENSE). Security issues: see [SECURITY.md](SECURITY.md).
