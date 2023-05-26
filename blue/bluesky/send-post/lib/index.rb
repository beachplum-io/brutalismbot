require 'json'

require 'yake'
require 'yake/support'

require_relative 'lib/bluesky'

BLUESKY ||= Bluesky.new

handler :send_post do |event|
  link  = event['Permalink']
  text  = event['Title']
  media = event['Media']

  # Send posts!
  posts = BLUESKY.thread(text: text, link: link, media: media)

  # Return enhanced event
  event.update('Posts' => posts, 'LastUpdate' => UTC.now.iso8601)
end
