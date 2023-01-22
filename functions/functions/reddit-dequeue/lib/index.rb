require 'time'

require 'yake'
require 'yake/support'

require_relative 'lib/reddit'

R_BRUTALISM ||= Reddit::Brutalism.new

AGE ||= (ENV['MIN_AGE_HOURS'] || '4').to_i.hours
TTL ||= (ENV['TTL_DAYS'] || '14').to_i.days

handler :reddit_dequeue do |event|
  start = Time.parse(event['ExclusiveStartTime']) rescue Time.at(0).utc
  queue = R_BRUTALISM.latest start
  post  = queue.shift if queue.first&.created_before?(UTC.now - AGE)

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
