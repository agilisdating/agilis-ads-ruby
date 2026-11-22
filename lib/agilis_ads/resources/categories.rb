# frozen_string_literal: true

module AgilisAds
  module Resources
    # GET /categories
    class Categories < Base
      def list
        call_api("GET", "/categories")
      end
    end
  end
end
