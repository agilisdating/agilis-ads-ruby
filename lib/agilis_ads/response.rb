# frozen_string_literal: true

module AgilisAds
  # The HTTP status, headers and raw body of an API response.
  class Response
    attr_reader :status, :headers, :body

    def initialize(status, headers, body)
      @status = status.to_i
      @headers = (headers || {}).to_h { |name, value| [name.to_s.downcase, Array(value).join(", ")] }
      @body = body.to_s
    end

    # A header by name, case-insensitively, or nil.
    def header(name)
      @headers[name.to_s.downcase]
    end

    def rate_limit_limit
      integer_header("x-ratelimit-limit")
    end

    def rate_limit_remaining
      integer_header("x-ratelimit-remaining")
    end

    def inspect
      "#<#{self.class.name} status=#{@status}>"
    end

    private

    def integer_header(name)
      value = header(name)
      value && Integer(value, exception: false)
    end
  end
end
