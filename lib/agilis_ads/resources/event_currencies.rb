# frozen_string_literal: true

module AgilisAds
  module Resources
    # GET /event-currencies
    class EventCurrencies < Base
      def list
        call_api("GET", "/event-currencies")
      end
    end
  end
end
