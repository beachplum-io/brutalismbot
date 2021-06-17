require "json"

require "twitter"
require "yake"

require_relative "reddit/post"
require_relative "twitter/brutalismbot"

BRUTALISMBOT = Twitter::Brutalismbot.new

handler :transform do |event|
  post = Reddit::Post.new JSON.parse event["JSON"], symbolize_names: true
  post.to_twitter
end

handler :post do |event|
  BRUTALISMBOT.post(**JSON.parse(event.to_json, symbolize_names: true))
end
