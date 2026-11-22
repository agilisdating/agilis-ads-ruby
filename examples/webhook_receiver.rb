# frozen_string_literal: true

# A minimal Rack webhook receiver. Run with:
#   AGILIS_WEBHOOK_SECRET=whsec_... rackup examples/webhook_receiver.ru
# or mount WebhookReceiver in any Rack-based framework (Rails, Sinatra, Hanami).
require "agilis_ads"

class WebhookReceiver
  def initialize(secret = ENV.fetch("AGILIS_WEBHOOK_SECRET"))
    @secret = secret
  end

  def call(env)
    return [405, {}, []] unless env["REQUEST_METHOD"] == "POST"

    raw_body = env["rack.input"].read
    event = AgilisAds::Webhook.construct_event(raw_body, env["HTTP_AGILIS_SIGNATURE"], @secret)

    case event.type
    when "offer.started" then puts "Offer #{event.data.object.offer_id} started"
    when "event.published" then puts "Event #{event.data.object.event_id} published"
    else puts "Received #{event.type} (#{event.id})"
    end

    [200, { "content-type" => "text/plain" }, ["ok"]]
  rescue AgilisAds::SignatureVerificationError
    [400, { "content-type" => "text/plain" }, ["invalid signature"]]
  end
end
