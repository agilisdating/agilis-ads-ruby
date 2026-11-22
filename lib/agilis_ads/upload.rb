# frozen_string_literal: true

module AgilisAds
  # A file to send in a multipart request, such as an Offer or Event image.
  #
  #   AgilisAds::Upload.from_path("offer.png")
  #   AgilisAds::Upload.from_bytes(png_bytes, filename: "offer.png")
  #   AgilisAds::Upload.from_io(File.open("offer.png", "rb"))
  #
  # Anywhere an upload is accepted you can also pass a file path (String or
  # Pathname) or an open IO; the content type is detected from the file name.
  class Upload
    CONTENT_TYPES = {
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".gif" => "image/gif",
      ".webp" => "image/webp"
    }.freeze
    DEFAULT_CONTENT_TYPE = "application/octet-stream"

    attr_reader :filename, :content_type

    def self.from_path(path, filename: nil, content_type: nil)
      path = path.to_s
      new(-> { File.binread(path) }, filename: filename || File.basename(path), content_type: content_type)
    end

    def self.from_bytes(bytes, filename:, content_type: nil)
      new(-> { bytes.to_s.b }, filename: filename, content_type: content_type)
    end

    def self.from_io(io, filename: nil, content_type: nil)
      name = filename || (io.respond_to?(:path) && io.path ? File.basename(io.path.to_s) : "upload")
      new(-> { io.read.to_s.b }, filename: name, content_type: content_type)
    end

    # Converts a path, IO or Upload into an Upload.
    def self.coerce(value)
      case value
      when Upload then value
      when String, Pathname then from_path(value)
      else
        raise ArgumentError, "Cannot upload a #{value.class}" unless value.respond_to?(:read)

        from_io(value)
      end
    end

    def self.upload?(value)
      value.is_a?(Upload) || value.is_a?(Pathname) || (!value.is_a?(String) && value.respond_to?(:read))
    end

    def self.content_type_for(filename)
      CONTENT_TYPES.fetch(File.extname(filename.to_s).downcase, DEFAULT_CONTENT_TYPE)
    end

    def initialize(reader, filename:, content_type: nil)
      @reader = reader
      @filename = filename.to_s
      @content_type = content_type || self.class.content_type_for(@filename)
    end

    # The file's bytes (read once).
    def read
      @read ||= @reader.call.b
    end

    def inspect
      "#<#{self.class.name} filename=#{@filename.inspect} content_type=#{@content_type.inspect}>"
    end
  end
end
