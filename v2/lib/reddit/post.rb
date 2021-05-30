require "json"
require "time"

module Reddit
  class Post
    def initialize(data)
      @data = data
    end

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
      @data.to_json
    end

    def to_slack
      {
        text: title,
        blocks: media_urls.map do |media_url|
          [
            {
              type: "image",
              title: { type: "plain_text", text: "/r/brutalism", emoji: true },
              image_url: media_url,
              alt_text: title,
            },
            {
              type: "context",
              elements: [ { type: "mrkdwn", text: "<#{ permalink }|#{ title }>" } ],
            }
          ]
        end.flatten
      }
    end

    def to_twitter
      # Get status
      max    = 279 - permalink.length
      status = title.length <= max ? title : "#{ title[0..max] }…"
      status << "\n#{ permalink }"

      # Get media attachments
      media = media_urls.each_slice(4).to_a
      media.last.unshift media[-2].pop if media.size > 1 && media.last.size < 3

      media = media_urls.then do |urls|
        urls.each_slice case urls.count % 4
        when 1 then 3
        when 2 then 3
        else 4
        end
      end

      # Zip status with media
      media.zip([status]).map do |media, status|
        { status: status, media: media}.compact
      end.then do |updates|
        { updates: updates, count: updates.count }
      end
    end

    private

    def data
      @data.fetch("data", {})
    end

    def preview_images
      @data.dig("data", "preview", "images")
    end

    def media_metadata
      @data.dig("data", "media_metadata")
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
