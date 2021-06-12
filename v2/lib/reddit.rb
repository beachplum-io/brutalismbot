require "json"
require "time"

require "aws-sdk-cloudwatch"
require "yake"

require_relative "reddit/brutalism"
require_relative "reddit/metrics"
require_relative "reddit/utc"

MTX = Reddit::Metrics.new
NEW = Reddit::Brutalism.new
TTL = 90 * 24 * 60 * 60

handler :dequeue do |event|
  stop  = Time.parse event.fetch "MaxCreatedUTC", UTC.hours_ago(4).iso8601
  queue = NEW.latest
  post  = queue.shift if queue.first.created_before?(stop)

  {
    QueueSize: queue.size,
    NextPost: post.nil? ? nil : {
      CreatedUTC: post.created_utc.iso8601,
      TTL:        post.created_utc.to_i + TTL,
      JSON:       post.to_json,
      Media:      post.media_urls,
      Name:       post.name,
      Permalink:  post.permalink,
      Title:      post.title,
    }
  }.compact
end

handler :metrics do |event|
  MTX.publish(**JSON.parse(event.to_json, symbolize_names: true))
end
