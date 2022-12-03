require 'yake'
require 'yake/support'

require_relative 'lib/reddit'

handler :twitter_transform do |event|
  Reddit::Post.new(**event.symbolize_names).to_twitter
end
