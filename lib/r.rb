module R
  module Brutalism
    ENDPOINT   = ENV["ENDPOINT"]   || "https://www.reddit.com/r/brutalism"
    USER_AGENT = ENV["USER_AGENT"] || "brutalismbot 0.1"

    class Client
      def initialize(endpoint:nil, user_agent:nil)
        @endpoint   = endpoint   || ENDPOINT
        @user_agent = user_agent || USER_AGENT
      end

      def new_posts(**params)
        url = File.join @endpoint, "new.json"
        qry = URI.encode_www_form params
        uri = URI.parse "#{url}?#{qry}"
        PostCollection.new uri: uri, user_agent: @user_agent
      end

      def top_post(**params)
        url = File.join @endpoint, "top.json"
        qry = URI.encode_www_form params
        uri = URI.parse "#{url}?#{qry}"
        PostCollection.new(uri: uri, user_agent: @user_agent).each do |post|
          break post unless post.url.nil?
        end
      end
    end

    class PostCollection
      include Enumerable

      def initialize(uri:, user_agent:, min_time:nil)
        @uri        = uri
        @ssl        = uri.scheme == "https"
        @user_agent = user_agent
        @min_time   = min_time.to_i
      end

      def after(time)
        PostCollection.new uri: @uri, user_agent: @user_agent, min_time: time
      end

      def each
        puts "GET #{@uri}"
        Net::HTTP.start(@uri.host, @uri.port, use_ssl: @ssl) do |http|
          request  = Net::HTTP::Get.new @uri, "user-agent" => @user_agent
          response = JSON.parse http.request(request).body
          children = response.dig("data", "children") || []
          children.reverse.each do |child|
            post = Post[child]
            yield post if post.created_after @min_time
          end
        end
      end
    end

    class Post < Hash
      def created_after(time)
        created_utc.to_i > time.to_i
      end

      def created_utc
        Time.at(dig("data", "created_utc").to_i).utc
      end

      def permalink
        dig "data", "permalink"
      end

      def title
        dig "data", "title"
      end

      def to_slack
        {
          blocks: [
            {
              type: "image",
              title: {
                type: "plain_text",
                text: "/r/brutalism",
                emoji: true,
              },
              image_url: url,
              alt_text: title,
            },
            {
              type: "context",
              elements: [
                {
                  type: "mrkdwn",
                  text: "<https://reddit.com#{permalink}|#{title}>",
                },
              ],
            },
          ],
        }
      end

      def url
        images = dig "data", "preview", "images"
        source = images.map{|x| x["source"] }.compact.max do |a,b|
          a.slice("width", "height").values <=> b.slice("width", "height").values
        end
        CGI.unescapeHTML source.dig("url")
      rescue NoMethodError
        dig("data", "media_metadata")&.values&.first&.dig("s", "u")
      end
    end
  end
end
