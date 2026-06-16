# frozen_string_literal: true

require 'json'

require 'yake'

require_relative 'lib/bluesky'

BLUESKY ||= Bluesky.new

handler :post do |event|
  link  = event['Permalink']
  text  = event['Title']
  media = event['Media']

  # Send posts!
  BLUESKY.thread(text:, link:, media:)
end
