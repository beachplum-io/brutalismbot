require 'yake'

require_relative 'lib/home'

HOME ||= Home.new

handler :home do |event|
  HOME.view event['user_id']
end
