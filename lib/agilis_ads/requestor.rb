# frozen_string_literal: true

module AgilisAds
  # Sends requests: headers, retries, and turning responses into objects or
  # errors. Used by the resources; not part of the public API.
  class Requestor
    NETWORK_ERRORS = [
      AgilisAds::ConnectionError,
      Timeout::Error,
      SocketError,
      SystemCallError,
      IOError,
      OpenSSL::SSL::SSLError,
      Net::ProtocolError,
      Net::HTTPBadResponse
    ].freeze
    RETRYABLE_SERVER_STATUSES = [500, 502, 503, 504].freeze
    INITIAL_RETRY_DELAY = 0.5
    MAX_RETRY_DELAY = 8.0
    REDACTED = "[redacted]"

    def initialize(api_key:, base_url:, timeout:, max_retries:, http_client:)
      @api_key = api_key
      @base_url = base_url
      @timeout = timeout
      @max_retries = max_retries
      @http_client = http_client
    end

    def inspect
      "#<#{self.class.name} base_url=#{@base_url.inspect}>"
    end

    # Sends one call and returns [parsed_body_hash, Response].
    def request(method, path, query: nil, json: nil, multipart: nil, headers: {})
      url = build_url(path, query)
      request_headers = base_headers.merge(headers)
      body = nil
      if multipart
        body, content_type = Multipart.encode(multipart)
        request_headers["Content-Type"] = content_type
      elsif json
        body = JSON.generate(json)
        request_headers["Content-Type"] = "application/json"
      elsif %w[POST PATCH PUT].include?(method)
        request_headers["Content-Length"] = "0"
      end

      send_with_retries(method, url, request_headers, body)
    end

    private

    def send_with_retries(method, url, headers, body)
      idempotent_post = method == "POST" && headers.key?("Idempotency-Key")
      can_retry_server_error = idempotent_post || %w[GET DELETE].include?(method)
      attempt = 0
      loop do
        begin
          status, response_headers, response_body =
            @http_client.call(method: method, url: url, headers: headers, body: body, timeout: @timeout)
        rescue *NETWORK_ERRORS => e
          if attempt < @max_retries
            sleep_before_retry(attempt, nil)
            attempt += 1
            next
          end
          raise connection_error(e)
        end

        response = Response.new(status, response_headers, response_body)
        if attempt < @max_retries && retryable?(response.status, can_retry_server_error)
          sleep_before_retry(attempt, response.header("retry-after"))
          attempt += 1
          next
        end

        return handle(response)
      end
    end

    def retryable?(status, can_retry_server_error)
      status == 429 || (can_retry_server_error && RETRYABLE_SERVER_STATUSES.include?(status))
    end

    def sleep_before_retry(attempt, retry_after)
      Kernel.sleep(retry_delay(attempt, retry_after))
    end

    def retry_delay(attempt, retry_after)
      seconds = parse_retry_after(retry_after)
      return seconds if seconds

      base = [INITIAL_RETRY_DELAY * (2**attempt), MAX_RETRY_DELAY].min
      jitter = (Kernel.rand * 0.5) - 0.25
      [base * (1 + jitter), MAX_RETRY_DELAY].min
    end

    def parse_retry_after(value)
      return nil if value.nil?

      seconds = Float(value.to_s.strip, exception: false)
      seconds && seconds >= 0 ? seconds : nil
    end

    def handle(response)
      parsed = parse_body(response.body)
      return_code = parsed.is_a?(Hash) ? parsed["return_code"] : nil
      success = response.status >= 200 && response.status < 300
      if success && !(return_code.is_a?(String) && return_code.start_with?("E"))
        return [parsed.is_a?(Hash) ? parsed : { "data" => parsed }, response]
      end

      raise error_for(response, parsed, return_code)
    end

    def parse_body(body)
      return {} if body.nil? || body.strip.empty?

      JSON.parse(body.dup.force_encoding(Encoding::UTF_8))
    rescue JSON::ParserError
      nil
    end

    def error_for(response, parsed, return_code)
      api_message = parsed.is_a?(Hash) ? parsed["message"] : nil
      message = scrub(api_message.is_a?(String) && !api_message.empty? ? api_message : "HTTP #{response.status}")
      options = {
        http_status: response.status,
        return_code: return_code,
        body: parsed.nil? ? response.body : parsed,
        headers: response.headers
      }
      case response.status
      when 200..299, 400, 422 then InvalidRequestError.new(message, **options)
      when 401 then AuthenticationError.new(message, **options)
      when 403 then PermissionError.new(message, **options)
      when 404 then NotFoundError.new(message, **options)
      when 409 then ConflictError.new(message, **options)
      when 429
        RateLimitError.new(message, retry_after: parse_retry_after(response.header("retry-after")), **options)
      else ApiError.new(message, **options)
      end
    end

    def connection_error(error)
      ConnectionError.new(scrub("Could not reach the Agilis API (#{error.class}: #{error.message})"))
    end

    def scrub(text)
      return text if @api_key.nil? || @api_key.empty?

      text.to_s.gsub(@api_key, REDACTED)
    end

    def base_headers
      {
        "x-api-key" => @api_key,
        "Accept" => "application/json",
        "User-Agent" => "agilis-ads-ruby/#{VERSION} (ruby #{RUBY_VERSION}; #{RUBY_PLATFORM})"
      }
    end

    def build_url(path, query)
      url = "#{@base_url}#{path}"
      pairs = (query || {}).reject { |_, value| value.nil? }
      return url if pairs.empty?

      encoded = pairs.map do |name, value|
        value = value.to_s unless value.is_a?(Array)
        [name.to_s, value]
      end
      "#{url}?#{URI.encode_www_form(encoded)}"
    end
  end
end
