# frozen_string_literal: true

module AgilisAds
  module Resources
    # Events: /events
    class Events < Base
      # POST /events/preview (multipart, with the image).
      def preview(params = nil, **fields)
        body = with_environment(merge_params(params, fields))
        call_api("POST", "/events/preview", multipart: body)
      end

      # POST /events (multipart). Sends an Idempotency-Key: your own
      # `idempotency_key:` or a random UUID, reused on every retry.
      def publish(params = nil, dry_run: false, idempotency_key: nil, **fields)
        body = with_environment(merge_params(params, fields))
        call_api("POST", "/events",
                 query: dry_run_query(dry_run), multipart: body, headers: idempotency_headers(idempotency_key))
      end

      # GET /events: one page. Use `auto_paging_each` on the result for all of them.
      def list(params = nil, **fields)
        list_page("/events", with_environment(merge_params(params, fields)))
      end

      # GET /events/{event_id}
      def get(event_id)
        call_api("GET", "/events/#{path_segment(event_id)}")
      end

      # PATCH /events/{event_id} (multipart). With a new image it is sent as a
      # POST with `X-HTTP-Method-Override: PATCH`.
      def edit(event_id, params = nil, **fields)
        body = merge_params(params, fields)
        path = "/events/#{path_segment(event_id)}"
        if Multipart.contains_upload?(body)
          call_api("POST", path, multipart: body, headers: { "X-HTTP-Method-Override" => "PATCH" })
        else
          call_api("PATCH", path, multipart: body)
        end
      end

      # DELETE /events/{event_id}
      def delete(event_id, dry_run: false)
        call_api("DELETE", "/events/#{path_segment(event_id)}", query: dry_run_query(dry_run))
      end

      # POST /events/{event_id}/reschedule (JSON: starts_at, ends_at).
      def reschedule(event_id, params = nil, **fields)
        call_api("POST", "/events/#{path_segment(event_id)}/reschedule", json: merge_params(params, fields))
      end

      # POST /events/{event_id}/cancel
      def cancel(event_id, dry_run: false)
        call_api("POST", "/events/#{path_segment(event_id)}/cancel", query: dry_run_query(dry_run))
      end

      # GET /events/{event_id}/analytics
      def analytics(event_id, params = nil, **fields)
        call_api("GET", "/events/#{path_segment(event_id)}/analytics", query: merge_params(params, fields))
      end
    end
  end
end
