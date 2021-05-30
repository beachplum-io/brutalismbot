require "cgi"
require "json"
require "logger"
require "open-uri"
require "time"

require "aws-sdk-dynamodb"

module Brutalismbot
  VERSION = "3.0.0"

  module Logging
    def logger
      @logger ||= Logger.new($stderr, progname: "-", formatter: -> (lvl, t, name, msg) { "#{ lvl } #{ name } #{ msg }\n" })
    end

    def logger=(logger)
      @logger = logger
    end
  end

  extend Logging

  module Enumerable
    include ::Enumerable

    def inspect
      "#<#{ self.class }>"
    end

    def [](index)
      to_a[index]
    end

    def all
      to_a
    end

    def last
      to_a.last
    end

    def size
      count
    end
  end

  module Itemizable
    def initialize(data)
      @data = JSON.parse(data.to_json)
    end

    def inspect
      "#<#{ self.class }>"
    end

    def [](key)
      @data[key.to_sym] || @data[key.to_s]
    end

    def to_h
      to_hash
    end

    def to_hash
      @data.to_h
    end

    def to_json
      to_hash.to_json
    end
  end

  module Parseable
    def parse(source, opts = {})
      new(**JSON.parse(source, opts))
    end
  end

  class Item
    extend Parseable
    include Itemizable
  end

  module Reddit
    module Listable
      include Enumerable

      def inspect
        "#<#{ self.class } #{ @endpoint }>"
      end

      def each
        Brutalismbot.logger.info("GET #{ @endpoint }")
        URI.open(@endpoint, **@headers) do |stream|
          # Parse Reddit response
          data  = JSON.parse(stream.read).dig("data", "children")
          # Convert to Reddit::Post items
          posts = data.map { |child| Post.new(**child) }
          # Yield posts
          posts.each { |post| yield post }
        end
      end
    end

    class Post < Item
      def created_utc
        Time.at(data["created_utc"]&.to_f).utc
      rescue TypeError
      end

      def inspect
        "#<#{ self.class } name: #{ name }>"
      end

      def key
        "#{ created_utc.iso8601 }/#{ name }"
      end

      def is_gallery?
        data["is_gallery"] || false
      end

      def is_self?
        data["is_self"] || false
      end

      def permalink
        File.join("https://www.reddit.com/", data["permalink"])
      end

      def title
        CGI.unescape_html(data["title"])
      rescue TypeError
      end

      ##
      # Get media URLs for post
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

      def to_slack
        Slack::Post.new(
          text: title,
          blocks: Enumerator.new do |enum|
            media_urls.map do |media_url|
              enum.yield(
                type: "image",
                title: { type: "plain_text", text: "/r/brutalism", emoji: true },
                image_url: media_url,
                alt_text: title,
              )
              enum.yield(
                type: "context",
                elements: [
                  { type: "mrkdwn", text: "<#{ permalink }|#{ title }>" },
                ],
              )
            end
          end.to_a
        )
      end

      def to_twitter
        # Get status
        max    = 280 - permalink.length - 1
        status = title.length <= max ? title : "#{ title[0...max - 1] }…"
        status << "\n#{ permalink }"

        # Get media attachments
        media = media_urls.then do |urls|
          size = case urls.count % 4
          when 1 then 3
          when 2 then 3
          else 4
          end

          urls.each_slice(size)
        end

        # Zip status with media
        media.zip([status]).map do |media, status|
          { status: status, media: media}.compact
        end.then do |updates|
          Twitter::Post.new(updates: updates, count: updates.count)
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
        media_metadata.values.map do |image|
          url = image.dig("s", "u")
          CGI.unescape_html(url) unless url.nil?
        end.compact
      end

      ##
      # Get media URLs from previews
      def media_urls_preview
        preview_images.map do |image|
          url = image.dig("source", "url")
          CGI.unescape_html(url) unless url.nil?
        end.compact
      end
    end

    class Queue
      include Listable

      ENDPOINT    = ENV["BRUTALISMBOT_REDDIT_ENDPOINT"]    || "https://www.reddit.com/r/brutalism/"
      USER_AGENT  = ENV["BRUTALISMBOT_REDDIT_USER_AGENT"]  || "Brutalismbot v#{ Brutalismbot::VERSION[/\d+/] }"
      LAG_SECONDS = ENV["BRUTALISMBOT_REDDIT_LAG_SECONDS"] || 3 * 60 * 60

      def initialize(resource = :new, endpoint:nil, user_agent:nil, lag_seconds:nil)
        @endpoint = File.join(endpoint || ENDPOINT, "#{ resource }.json")
        @headers  = { "user-agent" => user_agent || USER_AGENT }
        @max_time = Time.now.utc - (lag_seconds || LAG_SECONDS)
        @filters  = []
        before(@max_time)
      end

      def each
        super { |post| post }.sort_by(&:created_utc).each do |post|
          yield post if @filters.reduce(true) { |memo, block| memo && post.then(&block) }
        end
      end

      def after(time)
        tap { @filters << -> (post) { post.created_utc > time } }
      end

      def before(time)
        tap { @filters << -> (post) { post.created_utc <= time } }
      end
    end
  end

  module Slack
    class Post < Item
      def inspect
        "#<#{ self.class } #{ text }>"
      end

      def blocks
        @data["blocks"]
      end

      def text
        @data["text"]
      end
    end

    class Webhook < Item
      def inspect
        "#<#{ self.class } team_id: #{ team_id }, channel_id: #{ channel_id }>"
      end

      def key
        "#{ team_id }/#{ channel_id }"
      end

      def channel_id
        @data.dig("incoming_webhook", "channel_id")
      end

      def channel_name
        @data.dig("incoming_webhook", "channel")
      end

      def team_id
        @data["team_id"] || @data.dig("team", "id")
      end

      def team_name
        @data["team_name"] || @data.dig("team", "name")
      end

      def url
        URI(@data.dig("incoming_webhook", "url"))
      end
    end
  end

  module Twitter
    class Post < Item
      def inspect
        "#<#{ self.class } #{ status }>"
      end

      def status
        @data["updates"].map { |update| update["status"] }.join(" | ")
      end
    end
  end
end

##
# Lambda handler task wrapper
def handler(name, &block)
  define_method(name) do |event:nil, context:nil|
    Brutalismbot.logger.progname = context.nil? ? "-" : "RequestId: #{ context.aws_request_id }"
    Brutalismbot.logger.info("EVENT #{ event.to_json }")
    result = yield(event, context) if block_given?
    Brutalismbot.logger.info("RETURN #{ result.to_json }")
    result
  end
end

TABLE = Aws::DynamoDB::Table.new(name: "Brutalismbot")

handler :reddit_dequeue do |event|
  min_time     = Time.parse(event&.dig("MaxCreatedUTC") || "1970-01-01T00:00:00Z")
  post, *queue = Brutalismbot::Reddit::Queue.new.after(min_time).all
  { QueueSize: queue.count, NextPost: post.to_h }
end

handler :reddit_transform do |event|
  Brutalismbot::Reddit::Post.new(**event).then do |post|
    {
      GUID:        { S: "REDDIT/POST/#{ post.name }" },
      SORT:        { S: post.created_utc.iso8601 },
      KIND:        { S: "REDDIT/POST" },
      CREATED_UTC: { S: post.created_utc.iso8601 },
      JSON:        { S: post.to_json },
      NAME:        { S: post.name },
      PERMALINK:   { S: post.permalink },
      TITLE:       { S: post.title },
    }
  end
end

handler :slack_webhooks do
  transform = -> (item) { item.transform_keys(&:downcase).transform_keys(&:to_sym) }
  params = {
    index_name:                  "kind",
    projection_expression:       "TEAM_NAME,CHANNEL_NAME,WEBHOOK_URL",
    key_condition_expression:    "KIND = :KIND",
    expression_attribute_values: { ":KIND" => "SLACK/WEBHOOK" },
  }
  TABLE.query(**params).items.map(&transform)
end

handler :slack_transform do |event|
  Brutalismbot::Reddit::Post.new(**event).to_slack
end

handler :twitter_transform do |event|
  Brutalismbot::Reddit::Post.new(**event).to_twitter
end

handler :slack_transform_2 do |event|
  Brutalismbot::Reddit::Post.new(**event).then do |post|
    Brutalismbot::Slack::Webhook.new(**event["SlackWebhook"]).then do |webhook|
      {
        GUID:         { S: "SLACK/POST/#{ webhook.key }/#{ post.name }" },
        SORT:         { S: post.created_utc.iso8601 },
        JSON:         { S: post.to_slack.to_json },
        NAME:         { S: post.name },
        TEAM_ID:      { S: webhook.team_id },
        TEAM_NAME:    { S: webhook.team_name },
        CHANNEL_ID:   { S: webhook.team_id },
        CHANNEL_NAME: { S: webhook.team_name },
        WEBHOOK_KEY:  { S: webhook.key },
        WEBHOOK_URL:  { S: webhook.url.to_s },
      }
    end
  end
end

handler :twitter_transform_2 do |event|
  Brutalismbot::Reddit::Post.new(**event["NextPost"]).then do |post|
    {
      GUID:        { S: "TWITTER/POST/@brutalismbot/#{ post.name }" },
      SORT:        { S: post.created_utc.iso8601 },
      KIND:        { S: "TWITTER/POST" },
      JSON:        { S: post.to_twitter.to_json },
      NAME:        { S: post.name },
      PERMALINK:   { S: post.permalink },
      TITLE:       { S: post.title },
    }
  end
end
