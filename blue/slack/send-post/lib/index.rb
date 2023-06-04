require 'json'
require 'net/http'

require 'yake'
require 'yake/support'

require_relative 'lib/slack'

handler :send_post do |event|
  # Extract data
  channel = event['channel']
  link    = event['link']
  media   = event['media']
  text    = event['text']
  token   = event['token']
  url     = event['url']

  # Set up request
  headers = {
    'authorization' => "Bearer #{token}",
    'content-type'  => 'application/json; charset=utf-8',
  }
  body = {
    channel: channel,
    text:    text,
    blocks:  Slack.blocks(text, link, media),
  }.compact

  # Send request
  uri = URI url
  req = Net::HTTP::Post.new(uri.path, **headers)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(req, body.to_json).body.to_h_from_json
  end

  # Return request and response
  {
    url: url,
    req: body,
    res: res,
  }
end
