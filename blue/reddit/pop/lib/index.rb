require 'time'

require 'yake'
require 'yake/support'

require_relative 'lib/reddit'

R_BRUTALISM ||= Reddit::Brutalism.new

AGE ||= (ENV['MIN_AGE_HOURS'] ||  '4').to_i.hours
TTL ||= (ENV['TTL_DAYS']      || '14').to_i.days

handler :pop do |event|
  start = event['ExclusiveStartTime'].utc rescue Time.at(0).utc
  queue = R_BRUTALISM.latest start
  post  = queue.shift if queue.first&.created_before?(UTC.now - AGE)

  { QueueSize: queue.size, NextPost: post&.to_item }.compact
end
