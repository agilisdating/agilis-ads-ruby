# frozen_string_literal: true

module AgilisAds
  # The entry point of the SDK.
  #
  #   client = AgilisAds::Client.new(api_key: ENV.fetch("AGILIS_API_KEY"))
  #   client.categories.list
  #   client.offers.list(limit: 50).auto_paging_each { |offer| puts offer.title }
  class Client
    DEFAULT_BASE_URL = "https://ads.agilis.dating"
    DEFAULT_TIMEOUT = 60
    DEFAULT_MAX_RETRIES = 2

    attr_reader :base_url, :timeout, :max_retries, :mode,
                :categories, :interests, :offers, :event_categories, :event_currencies,
                :event_config, :events, :webhook_endpoints, :webhook_events, :webhooks

    # api_key     - your key (pk_test_... or pk_live_...); defaults to ENV["AGILIS_API_KEY"]
    # base_url    - defaults to https://ads.agilis.dating
    # timeout     - seconds per attempt, default 60
    # max_retries - default 2
    # http_client - an object with `call(method:, url:, headers:, body:, timeout:)`
    #               returning [status, headers, body]; defaults to NetHttpClient
    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES, http_client: nil)
      api_key ||= ENV.fetch("AGILIS_API_KEY", nil)
      if api_key.nil? || api_key.to_s.strip.empty?
        raise ArgumentError, "No API key: pass api_key: or set the AGILIS_API_KEY environment variable"
      end

      @api_key = api_key.to_s.strip
      @mode = self.class.mode_for(@api_key)
      @base_url = base_url.to_s.chomp("/")
      @timeout = timeout
      @max_retries = Integer(max_retries)
      @requestor = Requestor.new(api_key: @api_key, base_url: @base_url, timeout: @timeout,
                                 max_retries: @max_retries, http_client: http_client || NetHttpClient.new)
      build_resources
    end

    # "test" for a pk_test_ key, "live" for a pk_live_ key, otherwise nil.
    def self.mode_for(api_key)
      if api_key.start_with?("pk_test_")
        "test"
      elsif api_key.start_with?("pk_live_")
        "live"
      end
    end

    def test_mode?
      @mode == "test"
    end

    def live_mode?
      @mode == "live"
    end

    def inspect
      "#<#{self.class.name} mode=#{@mode.inspect} base_url=#{@base_url.inspect}>"
    end
    alias to_s inspect

    private

    attr_reader :requestor

    def build_resources
      @categories = Resources::Categories.new(self)
      @interests = Resources::Interests.new(self)
      @offers = Resources::Offers.new(self)
      @event_categories = Resources::EventCategories.new(self)
      @event_currencies = Resources::EventCurrencies.new(self)
      @event_config = Resources::EventConfig.new(self)
      @events = Resources::Events.new(self)
      @webhook_endpoints = Resources::WebhookEndpoints.new(self)
      @webhook_events = Resources::WebhookEvents.new(self)
      @webhooks = Resources::Webhooks.new(self)
    end
  end
end
