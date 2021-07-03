require 'yake'

require_relative 'lib/common'
require_relative 'lib/reddit/post'
require_relative 'lib/twitter/brutalismbot'

TWITTER = Twitter::Brutalismbot.new

handler :transform do |event|
  Reddit::Post.new(event.symbolize_names).to_twitter
end

handler :post do |event|
  TWITTER.post(**event.symbolize_names)
end
