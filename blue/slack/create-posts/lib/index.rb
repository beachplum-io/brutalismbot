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
  images = Post.images(text, media)
  post   = Post.new(channel:, text:, link:, images:)

  # Return request
  {
    'method'  => 'POST',
    'url'     => url,
    'body'    => post.to_h,
    'headers' => {
      'authorization' => "Bearer #{token}",
      'content-type'  => 'application/json; charset=utf-8',
    },
  }
end
