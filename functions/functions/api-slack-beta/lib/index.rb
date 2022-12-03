require 'yake/api'
require 'yake/support'

require_relative 'lib/slack'

SLACK ||= Slack::Client.new

header 'content-type' => 'application/json; charset=utf-8'

get '/health' do
  respond 200, { ok: true }.to_json
end

get '/install' do
  respond 302, 'location' => SLACK.install_uri
end

get '/oauth/v2' do |event|
  respond 302, 'location' => SLACK.install(event)
end

head '/health' do
  respond 200, { ok: true }.to_json
end

head '/install' do
  respond 302, 'location' => SLACK.install_uri
end

post '/health' do
  respond 200, { ok: true }.to_json
end

post '/callbacks' do |event|
  SLACK.verify event
  event['body'] = event['body'].then do |body|
    payload    = body.to_h_from_form['payload'].to_h_from_json
    action_id  = -> (action) { action['action_id'] }
    action_ids = payload['actions'].map(&action_id)
    payload.update('action_ids' => action_ids).to_json
  end
  SLACK.publish event
  respond 200
end

post '/events' do |event|
  SLACK.verify event
  SLACK.publish event
  respond 200
end

post '/slash/{cmd}' do |event|
  text = "```#{JSON.pretty_generate event}```"
  respond 200, { text: text }.to_json
end

handler :proxy do |event|
  route event
rescue Yake::Errors::Forbidden => err
  respond 403, { code: 403, message: err.to_s }.to_json
rescue => err
  respond 500, { code: 500, message: err.to_s }.to_json
end
