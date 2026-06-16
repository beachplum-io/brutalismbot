# frozen_string_literal: true

require 'yake'

require_relative 'lib/post'

handler :post do |event|
  # Extract data
  channel = event['Channel']
  link    = event['Permalink']
  media   = event['Media']
  text    = event['Text']
  token   = event['Token']
  url     = event['Url']

  # Compose post body
  post = Post.new(url:, token:, channel:, text:, link:, media:)

  # Return request/response
  { Request: post.request, Response: post.response }
end
