# frozen_string_literal: true

module AgilisAds
  module Resources
    # GET /interests
    class Interests < Base
      def list
        call_api("GET", "/interests")
      end
    end
  end
end
