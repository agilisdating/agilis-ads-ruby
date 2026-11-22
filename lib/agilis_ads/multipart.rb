# frozen_string_literal: true

module AgilisAds
  # Builds multipart/form-data bodies.
  #
  # Arrays are sent as repeated parts named with "[]" (`location[]`,
  # `gender[]`, `interests[]`), a hash as bracketed names (`crop: { x: 0 }`
  # becomes `crop[x]`), and uploads as file parts. nil values are left out.
  module Multipart
    CRLF = "\r\n"

    module_function

    # Returns [body, content_type].
    def encode(params, boundary: "AgilisAdsBoundary#{SecureRandom.hex(16)}")
      body = String.new(encoding: Encoding::BINARY)
      params.each do |name, value|
        each_part(name.to_s, value) { |part_name, part| body << part_bytes(boundary, part_name, part) }
      end
      body << "--#{boundary}--#{CRLF}".b
      [body, "multipart/form-data; boundary=#{boundary}"]
    end

    def each_part(name, value, &block)
      case value
      when nil then nil
      when Array
        array_name = name.end_with?("[]") ? name : "#{name}[]"
        value.each { |item| block.call(array_name, item) unless item.nil? }
      when Hash
        value.each { |key, item| each_part("#{name}[#{key}]", item, &block) }
      else
        block.call(name, name == "image" && value.is_a?(String) ? Upload.from_path(value) : value)
      end
    end

    def part_bytes(boundary, name, value)
      head = +"--#{boundary}#{CRLF}"
      if Upload.upload?(value)
        upload = Upload.coerce(value)
        head << "Content-Disposition: form-data; name=\"#{escape(name)}\"; "
        head << "filename=\"#{escape(upload.filename)}\"#{CRLF}"
        head << "Content-Type: #{upload.content_type}#{CRLF}#{CRLF}"
        head.b + upload.read + CRLF.b
      else
        head << "Content-Disposition: form-data; name=\"#{escape(name)}\"#{CRLF}#{CRLF}"
        head.b + scalar(value).b + CRLF.b
      end
    end

    def scalar(value)
      case value
      when true then "true"
      when false then "false"
      when Time then value.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      else value.to_s.encode(Encoding::UTF_8)
      end
    end

    def escape(text)
      text.to_s.gsub(/["\r\n\\]/) { |char| format("%%%02X", char.ord) }
    end

    def contains_upload?(params)
      params.any? do |name, value|
        Upload.upload?(value) || (name.to_s == "image" && value.is_a?(String))
      end
    end
  end
end
