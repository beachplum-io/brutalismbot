require "time"

require "yake"

require_relative "reddit/brutalism"
require_relative "reddit/utc"

NEW = Reddit::Brutalism.new
TTL = 90 * 24 * 60 * 60

handler :dequeue do |event|
  start = Time.parse event.fetch "MinCreatedUTC", UTC.epoch.iso8601
  stop  = Time.parse event.fetch "MaxCreatedUTC", UTC.hours_ago(4).iso8601
  queue = NEW.between(start, stop).reject(&:is_self?).sort_by(&:created_utc)
  post  = queue.shift
  raise IndexError, "No new posts" if post.nil?

  {
    QueueSize: queue.size,
    NextPost: {
      CreatedUTC: post.created_utc.iso8601,
      TTL:        post.created_utc.to_i + TTL,
      JSON:       post.to_json,
      Media:      post.media_urls,
      Name:       post.name,
      Permalink:  post.permalink,
      Title:      post.title,
    }
  }
end
