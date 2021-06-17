require "json"
require "time"

require "aws-sdk-cloudwatch"
require "yake"

require_relative "reddit/brutalism"
require_relative "reddit/metrics"

class Hash
  def symbolize_names() JSON.parse to_json, symbolize_names: true end
end

class Integer
  def days() hours * 24 end
  def hours() minutes * 60 end
  def minutes() seconds * 60 end
  def seconds() self end
end

class UTC < Time
  def self.now() super.utc end
end

MTX = Reddit::Metrics.new
NEW = Reddit::Brutalism.new
TTL = 14.days

handler :dequeue do |event|
  queue = NEW.latest
  post  = queue.shift if queue.first&.created_before?(UTC.now - 4.hours)

  {
    QueueSize: queue.size,
    NextPost: post.nil? ? nil : {
      CREATED_UTC: post.created_utc.iso8601,
      DATA:        post.to_h,
      NAME:        post.name,
      PERMALINK:   post.permalink,
      TITLE:       post.title,
      TTL:         post.created_utc.to_i + TTL,
    }
  }.compact
end

handler :itemize do |event|
  post = Reddit::Post.new event.symbolize_names
  {
    GUID:        { S: post.name },
    SORT:        { S: "REDDIT/SORT" },
    CREATED_UTC: { S: post.created_utc.iso8601 },
    JSON:        { S: post.to_json },
    MEDIA:       { L: post.media.map { |x| { S: x.last[:u] } } },
    NAME:        { S: post.name },
    PERMALINK:   { S: post.permalink },
    TITLE:       { S: post.title },
    TTL:         { N: (post.created_utc.to_i + TTL).to_s },
  }
end

handler :metrics do |event|
  MTX.put_metric_data(**event.symbolize_names)
end
