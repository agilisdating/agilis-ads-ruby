# frozen_string_literal: true

module AgilisAds
  module Resources
    # Webhook endpoints: /webhook-endpoints
    class WebhookEndpoints < Base
      # GET /webhook-endpoints
      def list
        call_api("GET", "/webhook-endpoints")
      end

      # POST /webhook-endpoints (JSON). The response holds `secret`, shown only this once.
      def create(params = nil, **fields)
        call_api("POST", "/webhook-endpoints", json: merge_params(params, fields))
      end

      # GET /webhook-endpoints/{endpoint_id}
      def get(endpoint_id)
        call_api("GET", "/webhook-endpoints/#{path_segment(endpoint_id)}")
      end

      # PATCH /webhook-endpoints/{endpoint_id} (JSON).
      def update(endpoint_id, params = nil, **fields)
        call_api("PATCH", "/webhook-endpoints/#{path_segment(endpoint_id)}", json: merge_params(params, fields))
      end

      # DELETE /webhook-endpoints/{endpoint_id}
      def delete(endpoint_id)
        call_api("DELETE", "/webhook-endpoints/#{path_segment(endpoint_id)}")
      end

      # POST /webhook-endpoints/{endpoint_id}/roll-secret (JSON, optional expires_in).
      def roll_secret(endpoint_id, params = nil, **fields)
        call_api("POST", "/webhook-endpoints/#{path_segment(endpoint_id)}/roll-secret",
                 json: merge_params(params, fields))
      end

      # POST /webhook-endpoints/{endpoint_id}/test (JSON, optional type).
      def send_test(endpoint_id, params = nil, **fields)
        call_api("POST", "/webhook-endpoints/#{path_segment(endpoint_id)}/test", json: merge_params(params, fields))
      end
    end
  end
end
