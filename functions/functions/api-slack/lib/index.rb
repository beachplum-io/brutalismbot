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

post '/events' do |event|
  SLACK.verify event
  SLACK.publish event
  respond 200
end

handler :proxy do |event|
  route event
rescue Yake::Errors::Forbidden => err
  respond 403, { code: 403, message: err.to_s }.to_json
rescue => err
  respond 500, { code: 500, message: err.to_s }.to_json
end
