# frozen_string_literal: true

module AgilisAds
  module Resources
    # Offers: /offers
    class Offers < Base
      # POST /offers/price-estimate (JSON).
      def estimate_price(params = nil, **fields)
        body = with_environment(merge_params(params, fields))
        call_api("POST", "/offers/price-estimate", json: body)
      end

      # POST /offers (multipart, with the image). Sends an Idempotency-Key: your
      # own `idempotency_key:` or a random UUID, reused on every retry.
      def create(params = nil, dry_run: false, idempotency_key: nil, **fields)
        body = with_environment(merge_params(params, fields))
        call_api("POST", "/offers",
                 query: dry_run_query(dry_run), multipart: body, headers: idempotency_headers(idempotency_key))
      end

      # GET /offers: one page. Use `auto_paging_each` on the result for all of them.
      def list(params = nil, **fields)
        list_page("/offers", with_environment(merge_params(params, fields)))
      end

      # POST /offers/{offer_id}/pause
      def pause(offer_id)
        call_api("POST", "/offers/#{path_segment(offer_id)}/pause")
      end

      # POST /offers/{offer_id}/resume
      def resume(offer_id)
        call_api("POST", "/offers/#{path_segment(offer_id)}/resume")
      end

      # GET /offers/{offer_id}/analytics
      def analytics(offer_id, params = nil, **fields)
        call_api("GET", "/offers/#{path_segment(offer_id)}/analytics", query: merge_params(params, fields))
      end

      # DELETE /offers/{offer_id}
      def delete(offer_id, dry_run: false)
        call_api("DELETE", "/offers/#{path_segment(offer_id)}", query: dry_run_query(dry_run))
      end
    end
  end
end
