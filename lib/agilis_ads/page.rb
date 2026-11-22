# frozen_string_literal: true

module AgilisAds
  # One page of a cursor-paginated list (`offers.list`, `events.list`,
  # `webhook_events.list`).
  #
  # `page.data` is this page's items. `page.auto_paging_each` yields every item
  # on this page and the pages after it, following `next_cursor` until
  # `has_more` is false; without a block it returns an Enumerator.
  class Page < AgilisObject
    def initialize(values, last_response = nil, fetch_next: nil)
      super(values, last_response)
      @fetch_next = fetch_next
    end

    def data
      self[:data] || []
    end

    def pagination
      self[:pagination]
    end

    # Whether there is another page after this one.
    def more?
      source = pagination || self
      source[:has_more] == true
    end

    def next_cursor
      source = pagination || self
      source[:next_cursor]
    end

    # Iterates over this page's items only.
    def each(&)
      return data.each unless block_given?

      data.each(&)
      self
    end

    def to_a
      data
    end

    # The next page, or nil when this is the last one.
    def next_page
      return nil unless more? && next_cursor && @fetch_next

      @fetch_next.call(next_cursor)
    end

    # Every item on this page and the following pages.
    def auto_paging_each(&block)
      return enum_for(:auto_paging_each) unless block

      page = self
      while page
        page.data.each(&block)
        page = page.next_page
      end
      self
    end
  end
end
