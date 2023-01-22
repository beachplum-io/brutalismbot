require 'open-uri'

require 'yake/logger'
require 'yake/support'

require_relative 'post'

module Reddit
  class Brutalism
    include Enumerable
    include Yake::Logger

    def initialize(resource = :new, user_agent = nil)
      @resource   = resource
      @user_agent = user_agent || ENV['REDDIT_USER_AGENT'] || 'Brutalismbot'
    end

    def each
      uri = URI "https://www.reddit.com/r/brutalism/#{ @resource }.json?raw_json=1"
      logger.info("GET #{ uri }")
      URI.open(uri, 'user-agent' => @user_agent) do |stream|
        stream.read.to_h_from_json.symbolize_names.dig(:data, :children).each do |child|
          yield Post.new child[:data]
        end
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
