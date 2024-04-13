require 'yake'
require 'yake/support'

require_relative 'lib/twitter'

TWITTER ||= Twitter.new

handler :send_tweet do |event|
  link  = event['Permalink']
  text  = event['Title']
  media = event['Media']

  # Send Tweets!
  tweets = TWITTER.thread(text:, link:, media:)

  # Return enhanced event
  event.update('Posts' => tweets, 'LastUpdate' => UTC.now.iso8601)
end
