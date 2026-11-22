# frozen_string_literal: true

module AgilisAds
  # Base class of every error the SDK raises for an API call.
  class AgilisError < StandardError
    attr_reader :http_status, :return_code, :body, :headers

    def initialize(message = nil, http_status: nil, return_code: nil, body: nil, headers: nil)
      super(message)
      @http_status = http_status
      @return_code = return_code
      @body = body
      @headers = headers || {}
    end
  end

  # HTTP 401: the API key is missing, wrong or revoked.
  class AuthenticationError < AgilisError; end

  # HTTP 403: the key may not do this (for example the other mode's environment).
  class PermissionError < AgilisError; end

  # HTTP 404.
  class NotFoundError < AgilisError; end

  # HTTP 409.
  class ConflictError < AgilisError; end

  # HTTP 400 or 422, or HTTP 200 with a return_code starting with "E".
  class InvalidRequestError < AgilisError; end

  # HTTP 429.
  class RateLimitError < AgilisError
    # Seconds to wait, from the Retry-After header, or nil.
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil, **kwargs)
      super(message, **kwargs)
      @retry_after = retry_after
    end
  end

  # HTTP 5xx and any other unexpected status.
  class ApiError < AgilisError; end

  # No response was received (connection refused, DNS failure, timeout and so on).
  class ConnectionError < AgilisError; end

  # A webhook message could not be verified.
  class SignatureVerificationError < AgilisError
    # :header, :timestamp, :signature or :payload.
    attr_reader :reason

    def initialize(message = nil, reason: nil)
      super(message)
      @reason = reason
    end
  end
end
