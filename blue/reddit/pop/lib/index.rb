require 'time'

require 'yake'
require 'yake/support'

require_relative 'lib/reddit'

R_BRUTALISM ||= Reddit::Brutalism.new

AGE ||= (ENV['MIN_AGE_HOURS'] || '4').to_i.hours

handler :pop do |event|
  start = event['ExclusiveStartTime'].utc rescue Time.at(0).utc
  queue = R_BRUTALISM.latest start
  post  = queue.shift if queue.first&.created_before?(UTC.now - AGE)

  { QueueSize: queue.size, NextPost: post&.to_item }.compact
end

############################
#   RE-AUTHORIZING STEPS   #
############################
#
# https://www.reddit.com/prefs/apps
#
# client_id=<client_id>
# client_secret=<client_secret>
# state=Brutalismbot
# redirect_uri=https://www.brutalismbot.com/
# duration=permanent
# scope=read
#
# open "https://www.reddit.com/api/v1/authorize?client_id=$client_id&response_type=code&state=$state&redirect_uri=$redirect_uri&duration=$duration&scope=$scope"
#
# code=<copy from redirect URL>
#
# curl -X POST https://www.reddit.com/api/v1/access_token \
#   -H 'content-type: application/x-www-form-urlencoded' \
#   -A "$state" \
#   -u "$client_id:$client_secret" \
#   -d "grant_type=authorization_code&code=$code&redirect_uri=$redirect_uri" \
# | jq -r '.refresh_token'
