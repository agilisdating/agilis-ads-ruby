# frozen_string_literal: true

module AgilisAds
  module Resources
    # `client.webhooks.construct_event` is the same as AgilisAds::Webhook.construct_event.
    class Webhooks < Base
      def construct_event(raw_body, signature_header, secret, tolerance = Webhook::DEFAULT_TOLERANCE, now: nil)
        Webhook.construct_event(raw_body, signature_header, secret, tolerance, now: now)
      end
    end
  end
end
