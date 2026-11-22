# frozen_string_literal: true

module AgilisAds
  module Resources
    # Webhook events: /webhook-events
    class WebhookEvents < Base
      # GET /webhook-events: one page. Use `auto_paging_each` on the result for all of them.
      def list(params = nil, **fields)
        list_page("/webhook-events", merge_params(params, fields))
      end

      # GET /webhook-events/{webhook_event_id}
      def get(webhook_event_id)
        call_api("GET", "/webhook-events/#{path_segment(webhook_event_id)}")
      end

      # POST /webhook-events/{webhook_event_id}/resend (JSON, optional endpoint_id).
      def resend(webhook_event_id, params = nil, **fields)
        call_api("POST", "/webhook-events/#{path_segment(webhook_event_id)}/resend",
                 json: merge_params(params, fields))
      end
    end
  end
end
