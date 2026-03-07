require 'net/http'

require 'yake'
require 'yake/support'

require_relative 'lib/screener'

URL = 'https://slack.com/api/chat.postMessage'

handler :screen do |event|
  # Extract data
  key          = event['Key']
  token        = event['AccessToken']
  execution_id = event['ExecutionId']
  channel      = event['Channel']
  text         = event['Title']
  media        = event['Media']
  link         = event['Permalink']

  # Get images
  images = Screener.images(text, media)

  # Set up request
  headers = {
    'authorization' => "Bearer #{token}",
    'content-type'  => 'application/json; charset=utf-8'
  }
  body = Screener.new(channel:, text:, link:, images:, execution_id:, key:)

  # Send request
  uri = URI URL
  req = Net::HTTP::Post.new(uri.path, **headers)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(req, body.to_json)
  end

  # Return response body
  res.body.to_h_from_json
end
