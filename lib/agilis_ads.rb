# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "pathname"
require "securerandom"
require "uri"

require_relative "agilis_ads/version"
require_relative "agilis_ads/errors"
require_relative "agilis_ads/agilis_object"
require_relative "agilis_ads/response"
require_relative "agilis_ads/page"
require_relative "agilis_ads/upload"
require_relative "agilis_ads/multipart"
require_relative "agilis_ads/net_http_client"
require_relative "agilis_ads/requestor"
require_relative "agilis_ads/webhook"
require_relative "agilis_ads/resources/base"
require_relative "agilis_ads/resources/categories"
require_relative "agilis_ads/resources/interests"
require_relative "agilis_ads/resources/offers"
require_relative "agilis_ads/resources/event_categories"
require_relative "agilis_ads/resources/event_currencies"
require_relative "agilis_ads/resources/event_config"
require_relative "agilis_ads/resources/events"
require_relative "agilis_ads/resources/webhook_endpoints"
require_relative "agilis_ads/resources/webhook_events"
require_relative "agilis_ads/resources/webhooks"
require_relative "agilis_ads/client"

# Ruby client for the Agilis Advertising REST API.
module AgilisAds
end
