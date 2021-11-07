require 'aws-sdk-dynamodb'
require 'yake'

require_relative 'lib/common'
require_relative 'lib/reddit/brutalism'

TABLE       = Aws::DynamoDB::Table.new name: ENV['TABLE_NAME'] || 'Brutalismbot'
R_BRUTALISM = Reddit::Brutalism.new :new, TABLE

LAG = (ENV['LAG_HOURS'] || '8').to_i.hours
TTL = (ENV['TTL_DAYS'] || '14').to_i.days

handler :dequeue do |event|
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
  }
end
