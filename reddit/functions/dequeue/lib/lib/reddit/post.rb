require 'json'
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
      if is_self?
        []
      elsif is_gallery?
        media_gallery
      else
        media_preview
      end
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
        Id:         "/r/brutalism/#{name}",
        Kind:       'reddit/post',
        CreatedUTC: created_utc.iso8601,
        Name:       name,
        Title:      title,
        MediaURLs:  media_urls,
        JSON:       to_json,
      }
    end

    def to_slack
      blocks = media.map(&:last).each_with_index.map do |image,i|
        {
          type:      'image',
          image_url: image[:u],
          alt_text:  title,
          title: {
            type: 'plain_text',
            text: "/r/brutalism [#{ i + 1 }/#{ media.count }]",
            emoji: true
          }
        }
      end << {
        type: 'context',
        elements: [
          {
            type: 'mrkdwn',
            text: "<#{ permalink_url }|#{ title }>"
          }
        ]
      }

      { text: title, blocks: blocks }
    end

    def to_twitter
      # Get status
      max    = 279 - permalink_url.length
      status = title.length <= max ? title : "#{ title[0..max] }…"
      status << "\n#{ permalink_url }"

      # Zip status with media
      size    = (media.count % 4).between?(1, 2) ? 3 : 4
      updates = media.each_slice(size).zip([status]).map do |media, status|
        { status: status, media: media.map { |x| x.last[:u] } }.compact
      end

      # Return updates
      { updates: updates, count: updates.count }
    end

    private

    ##
    # Get media URLs from gallery
    def media_gallery
      area = -> (x) {  x[:x] * x[:y] }
      urls = -> (x) { dig(:media_metadata, x[:media_id])[:p].max_by(&area)[:u] }
      dig(:gallery_data, :items)&.map(&urls)
    end

    ##
    # Get media URLs from previews
    def media_preview
      area = -> (x) { x[:width] * x[:height] }
      urls = -> (x) { ([x[:source]] + x[:resolutions]).max_by(&area)[:url] }
      dig(:preview, :images)&.map(&urls)
    end
  end
end
