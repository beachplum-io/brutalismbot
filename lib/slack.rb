require 'yake'

require_relative 'lib/common'
require_relative 'lib/reddit/post'

handler :transform do |event|
  Reddit::Post.new(event.symbolize_names).to_slack
end
