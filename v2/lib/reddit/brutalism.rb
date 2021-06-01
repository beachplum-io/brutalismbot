require "open-uri"

require "yake/logger"

require_relative "post"

module Reddit
  class Brutalism
    include Enumerable
    include Yake::Logger

    attr_reader :headers

    def initialize(resource = :new, **headers)
      @uri     = URI "https://www.reddit.com/r/brutalism/#{ resource }.json?raw_json=1"
      @headers = {
        "user-agent" => ENV["REDDIT_USER_AGENT"] || "Brutalismbot v2",
        **headers
      }
    end

    def each
      logger.info("GET #{ @uri }")
      URI.open(@uri, **@headers) do |stream|
        JSON.parse(stream.read).dig("data", "children").each do |child|
          yield Post.new child
        end
      end
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

    class << self
      def hot(**headers)
        new(:hot, **headers)
      end

      def top(**headers)
        new(:top, **headers)
      end
    end
  end
end
