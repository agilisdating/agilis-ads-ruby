# frozen_string_literal: true

module AgilisAds
  module Resources
    # GET /event-config
    class EventConfig < Base
      def get
        call_api("GET", "/event-config")
      end
    end
  end
end
