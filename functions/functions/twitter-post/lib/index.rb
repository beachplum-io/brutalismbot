require 'yake'
require 'yake/support'

require_relative 'lib/twitter'

TWITTER ||= Twitter::Brutalismbot.new

handler :twitter_post do |event|
  TWITTER.post(**event.symbolize_names)
end
