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

    def media
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
      media_metadata.values.map do |m|
        (m[:p] + [ m[:s] ]).sort_by { |i| i[:x] * i[:y] }
      end
    end

    ##
    # Get media URLs from previews
    def media_preview
      (preview&.dig(:images) || []).map do |m|
        (m[:resolutions] + [ m[:source] ]).map do |i|
          i.transform_keys { |k| { :url => :u, :width => :x, :height => :y }[k] }.slice(:y, :x, :u)
        end.sort_by { |i| i[:x] * i[:y] }
      end
    end
  end
end
