# frozen_string_literal: true

module AgilisAds
  module Resources
    # GET /event-categories
    class EventCategories < Base
      def list
        call_api("GET", "/event-categories")
      end
    end
  end
end
