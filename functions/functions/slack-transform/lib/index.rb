require 'yake'
require 'yake/support'

require_relative 'lib/reddit'

handler :transform do |event|
  Reddit::Post.new(**event.symbolize_names).to_slack
end
