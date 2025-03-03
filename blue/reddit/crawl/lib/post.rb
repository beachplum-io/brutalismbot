require 'json'
require 'ostruct'
require 'time'

module Reddit
  class Post < OpenStruct
    def initialize(...)
      super
      yield self if block_given?
    end

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
      Time.at(self['created_utc']&.to_f).utc
    rescue TypeError
    end

    def is_gallery?
      is_gallery || false
    end

    def is_self?
      is_self || false
    end

    def media_urls
      is_gallery? ? media_gallery : media_preview || []
    end

    def permalink_url
      "https://www.reddit.com#{ permalink }"
    end

    def to_h
      @table.sort.to_h
    end

    def to_json
      to_h.to_json
    end

    def to_item
      {
        Id:         "backlog/#{created_utc.to_i}",
        Kind:       'backlog',
        Json:       to_json,
        LastUpdate: created_utc.iso8601,
        Media:      media_urls.to_json,
        Name:       name,
        Permalink:  permalink_url,
        Status:     'New',
        Title:      title,
      }
    end

    private

    ##
    # Get media URLs from gallery
    def media_gallery
      area = -> (x) {  x[:x] * x[:y] }
      imgs = -> (x) do
        img = dig(:media_metadata, x[:media_id].to_sym)
        (img[:p] + [img[:s]]).sort_by(&area).reverse rescue nil
      end
      dig(:gallery_data, :items)&.map(&imgs).compact
    end

    ##
    # Get media URLs from previews
    def media_preview
      area = -> (x) { x[:width] * x[:height] }
      smol = -> (x) { { x: x[:width], y: x[:height], u: x[:url] } }
      imgs = -> (x) { (x[:resolutions] + [x[:source]]).sort_by(&area).reverse.map(&smol) }
      dig(:preview, :images)&.map(&imgs)
    end
  end
end
