# frozen_string_literal: true

module AgilisAds
  # Verifies webhook messages sent by Agilis.
  module Webhook
    DEFAULT_TOLERANCE = 300
    SIGNATURE_HEADER = "Agilis-Signature"

    module_function

    # Checks the `Agilis-Signature` header of a received webhook and returns the
    # parsed event as an AgilisObject.
    #
    # raw_body         - the request body exactly as received (not re-encoded JSON)
    # signature_header - the value of the Agilis-Signature header
    # secret           - your endpoint's signing secret (whsec_...)
    # tolerance        - how many seconds the timestamp may differ from now
    #
    # Raises AgilisAds::SignatureVerificationError when the header is missing or
    # malformed, the timestamp is outside the tolerance, or no v1 signature matches.
    def construct_event(raw_body, signature_header, secret, tolerance = DEFAULT_TOLERANCE, now: nil)
      raise ArgumentError, "A webhook secret is required" if secret.nil? || secret.to_s.empty?

      payload = raw_body.to_s.b
      timestamp, signatures = parse_header(signature_header)
      current = (now || Time.now).to_i
      if (current - timestamp.to_i).abs > tolerance.to_i
        raise SignatureVerificationError.new("The timestamp is outside the tolerance", reason: :timestamp)
      end

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, "#{timestamp}.".b + payload)
      unless signatures.any? { |signature| OpenSSL.secure_compare(expected, signature) }
        raise SignatureVerificationError.new("No signature matches the expected signature", reason: :signature)
      end

      parse_event(payload)
    end

    # Returns [timestamp string, [v1 signatures]] or raises SignatureVerificationError.
    def parse_header(header)
      timestamp = nil
      signatures = []
      header.to_s.split(",").each do |item|
        key, value = item.strip.split("=", 2)
        next if value.nil?

        case key
        when "t" then timestamp = value
        when "v1" then signatures << value
        end
      end

      raise header_error("The signature header has no timestamp") if timestamp.nil?
      raise header_error("The signature header's timestamp is not a number") unless timestamp.match?(/\A\d+\z/)
      raise header_error("The signature header has no v1 signature") if signatures.empty?

      [timestamp, signatures]
    end

    def parse_event(payload)
      values = JSON.parse(payload.dup.force_encoding(Encoding::UTF_8))
      raise JSON::ParserError, "not an object" unless values.is_a?(Hash)

      AgilisObject.new(values)
    rescue JSON::ParserError
      raise SignatureVerificationError.new("The webhook body is not a JSON object", reason: :payload)
    end

    def header_error(message)
      SignatureVerificationError.new(message, reason: :header)
    end
  end
end
