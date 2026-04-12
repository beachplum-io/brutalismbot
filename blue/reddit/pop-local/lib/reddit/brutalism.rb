require 'net/http'

require 'yake/logger'
require 'yake/support'

require_relative 'post'

module Reddit
  class Brutalism
    include Enumerable
    include Yake::Logger

    USER_AGENT ||= ENV['USER_AGENT'] || 'Brutalismbot'

    def each
      uri = URI('https://oauth.reddit.com/r/brutalism/new.json?raw_json=1')
      hed = { 'user-agent' => USER_AGENT }
      req = Net::HTTP::Get.new(uri, **hed)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        logger.info("GET #{ uri }")
        http.request(req)
      end

      res.body.to_h_from_json.symbolize_names.dig(:data, :children).each do |child|
        post = Post.new child[:data]
        yield post if post.media_urls.any?
      end
    end

    def all
      to_a
    end

    def latest(start)
      after(start).reject(&:is_self?).sort_by(&:created_utc)
    end

    def after(start)
      select { |post| post.created_utc > start }
    end

    def between(start, stop)
      select { |post| post.created_utc > start && post.created_utc < stop }
    end

    def before(stop)
      select { |post| post.created_utc < stop }
    end
  end
end
