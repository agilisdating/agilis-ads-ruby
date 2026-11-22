# frozen_string_literal: true

module AgilisAds
  # A JSON object returned by the API.
  #
  # Every field is readable as a method (`offer.offer_id`) or with `[]`
  # (`offer[:offer_id]` or `offer["offer_id"]`). Fields the SDK does not know
  # about are kept, so a new API field never breaks a client. Nested objects
  # are AgilisObjects too; `to_h` returns plain Ruby hashes with symbol keys.
  class AgilisObject
    # The HTTP response this object came from (status and headers), or nil for
    # nested objects and webhook events.
    attr_reader :last_response

    def initialize(values = {}, last_response = nil)
      @values = (values || {}).to_h { |key, value| [key.to_s, value] }
      @last_response = last_response
      @converted = {}
    end

    def [](key)
      key = key.to_s
      return nil unless @values.key?(key)

      @converted.fetch(key) { @converted[key] = self.class.convert(@values[key]) }
    end

    def key?(key)
      @values.key?(key.to_s)
    end

    def keys
      @values.keys.map(&:to_sym)
    end

    def dig(key, *rest)
      value = self[key]
      return value if rest.empty? || value.nil?

      value.dig(*rest)
    end

    def each
      return to_enum(:each) unless block_given?

      keys.each { |key| yield key, self[key] }
      self
    end

    def to_h
      self.class.deep_symbolize(@values)
    end

    def to_json(*args)
      JSON.generate(@values, *args)
    end

    def ==(other)
      other.is_a?(AgilisObject) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def inspect
      "#<#{self.class.name} #{JSON.generate(@values)}>"
    end

    def to_s
      inspect
    end

    def respond_to_missing?(name, include_private = false)
      @values.key?(name.to_s) || super
    end

    def method_missing(name, *args)
      key = name.to_s
      return self[key] if args.empty? && @values.key?(key)

      super
    end

    # Wraps hashes in AgilisObject and arrays element by element.
    def self.convert(value)
      case value
      when Hash then AgilisObject.new(value)
      when Array then value.map { |item| convert(item) }
      else value
      end
    end

    def self.deep_symbolize(value)
      case value
      when Hash then value.to_h { |key, item| [key.to_sym, deep_symbolize(item)] }
      when Array then value.map { |item| deep_symbolize(item) }
      else value
      end
    end
  end
end
