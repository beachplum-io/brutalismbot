require 'json'
require 'net/http'

require 'yake'
require 'yake/support'

require_relative 'lib/post'

handler :get_post do |event|
  # Extract data
  channel = event['channel']
  link    = event['link']
  media   = event['media']
  text    = event['text']
  token   = event['token']
  url     = event['url']

  # Compose post body
  post = Post.new(
    channel: channel,
    text:    text,
    link:    link,
    images:  Post.images(text, media),
  )

  # Return request
  {
    'method' => 'POST',
    'url' => url,
    'body' => post.to_h,
    'headers' => {
      'authorization' => "Bearer #{token}",
      'content-type'  => 'application/json; charset=utf-8',
    },
  }
end
