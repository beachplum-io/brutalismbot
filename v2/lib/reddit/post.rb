require "json"
require "time"

module Reddit
  class Post < OpenStruct
    def inspect
      "#<#{ self.class } #{ permalink }>"
    end

    def created_utc
      begin Time.at(data["created_utc"]&.to_f).utc rescue TypeError end
    end

    def is_gallery?
      data["is_gallery"] || false
    end

    def is_self?
      data["is_self"] || false
    end

    def permalink
      data["permalink"]
    end

    def title
      data["title"]
    end

    def media_urls
      if is_gallery?
        media_urls_gallery
      elsif preview_images
        media_urls_preview
      else
        []
      end
    end

    def name
      data["name"]
    end

    def to_json
      to_h.to_json
    end

    private

    def data
      fetch("data", {})
    end

    def preview_images
      dig("data", "preview", "images")
    end

    def media_metadata
      dig("data", "media_metadata")
    end

    ##
    # Get media URLs from gallery
    def media_urls_gallery
      media_metadata.values.map { |i| i.dig("s", "u") }
    end

    ##
    # Get media URLs from previews
    def media_urls_preview
      preview_images.map { |i| i.dig("source", "url") }.compact
    end
  end
end
