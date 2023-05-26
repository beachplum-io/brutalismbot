require 'net/http'

require 'yake'
require 'yake/support'

require_relative 'lib/blocks'

URL = 'https://slack.com/api/chat.postMessage'

handler :screen do |event|
  # Extract data
  token        = event['AccessToken']
  execution_id = event['ExecutionId']
  channel      = event['Channel']
  text         = event['Title']
  media        = event['Media']
  link         = event['Permalink']

  # Set up request
  headers = {
    'authorization' => "Bearer #{token}",
    'content-type'  => 'application/json; charset=utf-8'
  }
  body = {
    channel: channel,
    text:    text,
    attachments: [{
      color:  '#06E886',
      blocks: blocks(text, link, media, execution_id),
    }]
  }

  # Send request
  uri = URI URL
  req = Net::HTTP::Post.new(uri.path, **headers)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(req, body.to_json).body.to_h_from_json
  end

  # Return response body
  res
end
