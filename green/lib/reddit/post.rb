require 'json'
require 'time'

module Reddit
  class Post
    def initialize(data)
      @data = data
    end

    def inspect
      "#<#{self.class} #{@data['created_utc'].to_i} #{@data['title']}>"
    end

    def created_utc
      Time.at(@data['created_utc']).utc
    end

    def is_gallery?
      @data['is_gallery'] || false
    end

    def is_self?
      @data['is_self'] || false
    end

    def media_urls
      (is_gallery? ? media_gallery : media_preview) || []
    end

    def permalink_url
      "https://www.reddit.com#{@data['permalink']}"
    end

    def to_item
      {
        Id:         "r/brutalism/#{@data['name']}",
        Kind:       'reddit.post.new',
        CreatedUtc: created_utc.iso8601,
        Json:       @data.to_json,
        Media:      media_urls.to_json,
        Name:       @data['name'],
        Permalink:  permalink_url,
        Title:      @data['title'],
      }
    end

    private

    ##
    # Get media URLs from gallery
    def media_gallery
      area = -> (x) {  x[:x] * x[:y] }
      imgs = -> (x) do
        img = @data.dig('media_metadata', x['media_id'].to_sym)
        (img['p'] + [img['s']]).sort_by(&area).reverse
      rescue
        nil
      end
      @data.dig('gallery_data', 'items')&.filter_map(&imgs)
    end

    ##
    # Get media URLs from previews
    def media_preview
      area = -> (x) { x['width'] * x['height'] }
      smol = -> (x) { { 'x' => x['width'], 'y' => x['height'], 'u' => x['url'] } }
      imgs = -> (x) { (x['resolutions'] + [x['source']]).sort_by(&area).reverse.map(&smol) }
      @data.dig('preview', 'images')&.map(&imgs)
    end
  end
end
