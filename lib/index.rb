require "json"

require "aws-sdk-dynamodb"
require "yake"

require_relative "lib/common"
require_relative "lib/reddit/brutalism"
require_relative "lib/reddit/metrics"
require_relative "lib/reddit/post"
require_relative "lib/twitter/brutalismbot"

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

handler :slack_transform do |event|
  Reddit::Post.new(event.symbolize_names).to_slack
end

handler :twitter_post do |event|
  post = Reddit::Post.new event["DATA"].symbolize_names
  TWITTER.post(**post.to_twitter)
end
