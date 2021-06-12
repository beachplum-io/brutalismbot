require "json"
require "time"

module Reddit
  class Post < OpenStruct
    def inspect
      "#<#{ self.class } #{ permalink }>"
    end

    def created_after?(time)
      created_utc > time
    end

    def created_before?(time)
      created_utc < time
    end

    def created_utc
      begin Time.at(self["created_utc"]&.to_f).utc rescue TypeError end
    end

    def is_gallery?
      is_gallery || false
    end

    def is_self?
      is_self || false
    end

    def media_urls
      if is_gallery?
        media_urls_gallery
      elsif is_self?
        []
      else
        media_urls_preview
      end
    end

    def to_json
      to_h.to_json
    end

    private

    ##
    # Get media URLs from gallery
    def media_urls_gallery
      media_metadata.values.map { |i| i.dig(:s, :u) }
    end

    ##
    # Get media URLs from previews
    def media_urls_preview
      (preview&.dig(:images) || []).map { |i| i.dig(:source, :url) }.compact
    end
  end
end
