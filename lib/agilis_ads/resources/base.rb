# frozen_string_literal: true

module AgilisAds
  module Resources
    # Shared helpers for the resource classes.
    class Base
      def initialize(client)
        @client = client
      end

      def inspect
        "#<#{self.class.name}>"
      end

      private

      def requestor
        @client.send(:requestor)
      end

      # Merges a positional params hash with keyword fields; keys become strings
      # and Time values become ISO 8601 UTC strings.
      def merge_params(params, fields)
        merged = {}
        (params || {}).each { |key, value| merged[key.to_s] = normalize(value) }
        fields.each { |key, value| merged[key.to_s] = normalize(value) }
        merged
      end

      def normalize(value)
        case value
        when Time then value.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        when Hash then value.to_h { |key, item| [key.to_s, normalize(item)] }
        when Array then value.map { |item| normalize(item) }
        else value
        end
      end

      # Fills in `environment` from the key's mode when the caller left it out.
      def with_environment(params)
        return params if params.key?("environment") || @client.mode.nil?

        params.merge("environment" => @client.mode.upcase)
      end

      def path_segment(value)
        raise ArgumentError, "An id is required" if value.nil? || value.to_s.empty?

        value.to_s.b.gsub(/[^A-Za-z0-9\-._~]/) { |char| format("%%%02X", char.ord) }
      end

      def dry_run_query(dry_run)
        dry_run ? { "dry_run" => "true" } : {}
      end

      def idempotency_headers(idempotency_key)
        { "Idempotency-Key" => (idempotency_key || SecureRandom.uuid).to_s }
      end

      def call_api(method, path, **options)
        values, response = requestor.request(method, path, **options)
        AgilisObject.new(values, response)
      end

      def list_page(path, query)
        values, response = requestor.request("GET", path, query: query)
        fetch_next = ->(cursor) { list_page(path, query.merge("cursor" => cursor)) }
        Page.new(values, response, fetch_next: fetch_next)
      end
    end
  end
end
