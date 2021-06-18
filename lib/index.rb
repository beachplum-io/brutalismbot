require "json"

require "aws-sdk-dynamodb"
require "yake"

require_relative "lib/reddit/brutalism"
require_relative "lib/reddit/metrics"
require_relative "lib/reddit/post"
require_relative "lib/twitter/brutalismbot"

class Hash
  def symbolize_names() JSON.parse to_json, symbolize_names: true end
end

class Integer
  def days() hours * 24 end
  def hours() minutes * 60 end
  def minutes() seconds * 60 end
  def seconds() self end
end

class String
  def camel_case() split(/_/).map(&:capitalize).join end
  def snake_case() gsub(/([a-z])([A-Z])/, '\1_\2').downcase end
end

class Symbol
  def camel_case() to_s.camel_case.to_sym end
  def snake_case() to_s.snake_case.to_sym end
end

class UTC < Time
  def self.now() super.utc end
end

TABLE       = Aws::DynamoDB::Table.new name: ENV["TABLE_NAME"] || "Brutalismbot"
R_BRUTALISM = Reddit::Brutalism.new :new, TABLE
METRICS     = Reddit::Metrics.new
TWITTER     = Twitter::Brutalismbot.new

LAG = 4.hours
TTL = 14.days

handler :dynamodb_query do |event|
  params = event.transform_keys(&:snake_case)
  TABLE.query(**params).to_h.transform_keys(&:camel_case)
end

handler :reddit_dequeue do |event|
  queue = R_BRUTALISM.latest
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

handler :reddit_metrics do |event|
  METRICS.put_metric_data(**event.symbolize_names)
end

handler :slack_post do |event|
  uri     = URI event["WEBHOOK_URL"]
  post    = Reddit::Post.new event["DATA"].symbolize_names
  headers = {
    "authorization" => "Bearer #{ event["ACCESS_TOKEN"] }",
    "content-type"  => "application/json; charset=utf-8"
  }
  res  = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    req = Net::HTTP::Post.new(uri.path, **headers)
    req.body = post.to_slack.to_json
    http.request req
  end

  {
    ok:         res.body.downcase == "ok",
    statusCode: res.code,
    body:       res.body,
    headers:    res.each_header.sort.to_h,
  }
end

handler :twitter_post do |event|
  post = Reddit::Post.new event["DATA"].symbolize_names
  TWITTER.post(**post.to_twitter)
end
