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
LAG = 4.hours

handler :dequeue do |event|
  queue = NEW.latest
  post  = queue.shift if queue.first&.created_before?(UTC.now - LAG)

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

handler :metrics do |event|
  MTX.put_metric_data(**event.symbolize_names)
end
