require "logger"

require "aws-sdk-s3"
require "aws-sdk-secretsmanager"

require "brutalismbot"

DRYRUN         = !ENV["DRYRUN"].to_s.empty?
LIMIT          = ENV["LIMIT"]&.to_i
LOG_LEVEL      = ENV["LOG_LEVEL"]      || "INFO"
MIN_AGE        = ENV["MIN_AGE"]&.to_i  || 9000
TWITTER_SECRET = ENV["TWITTER_SECRET"] || "brutalismbot/twitter"

S3 = Aws::S3::Client.new
SM = Aws::SecretsManager::Client.new

{ secret_id: TWITTER_SECRET }.tap do |secret|
  puts "GET SECRET #{secret.to_json}"
  ENV.update JSON.parse SM.get_secret_value(**secret).secret_string
end

BRUTALISMBOT = Brutalismbot::Client.new(
  posts:   Brutalismbot::Posts::Client.new(client: S3),
  reddit:  Brutalismbot::Reddit::Client.new,
  slack:   Brutalismbot::Slack::Client.new(client: S3),
  twitter: Brutalismbot::Twitter::Client.new,
)

# --- State Machine handlers

##
# Pull new posts from /r/brutalism
#
# reddit_pull
# => [ { bucket: "…", key: "…", "url": "…" } ]
def reddit_pull(event:nil, context:nil)
  puts "EVENT #{event.to_json}"

  event.transform_keys!(&:to_sym)
  dryrun  = event.fetch :dryrun,  DRYRUN
  min_age = event.fetch :min_age, MIN_AGE
  limit   = event.fetch :limit,   LIMIT

  BRUTALISMBOT.pull dryrun: dryrun, min_age: min_age, limit: limit
end

##
# Get Slack webhooks
#
# slack_list
# => [ "…", "…" ]
def slack_list(event:nil, context:nil)
  puts "EVENT #{event.to_json}"

  BRUTALISMBOT.slack.list.map(&:webhook_url)
end

##
# Push post to Slack
#
# slack_push event: { bucket: "…", key: "…", webhook_url: "…" }
# => [ Net::HTTPOK, … ]
def slack_push(event:, context:nil)
  puts "EVENT #{event.to_json}"

  event.transform_keys!(&:to_sym)
  dryrun      = event.fetch :dryrun, DRYRUN
  bucket      = event.fetch :bucket
  key         = event.fetch :key
  webhook_url = event.fetch :webhook_url

  post = BRUTALISMBOT.posts.get bucket: bucket, key: key

  BRUTALISMBOT.slack.push post, webhook_url, dryrun: dryrun
end

##
# Push post to Twitter
#
# twitter_push event: { bucket: "…", key: "…" }
# => [ 1311805075975737346, … ]
def twitter_push(event:, context:nil)
  puts "EVENT #{event.to_json}"

  event.transform_keys!(&:to_sym)
  dryrun = event.fetch :dryrun, DRYRUN
  bucket = event.fetch :bucket
  key    = event.fetch :key

  post = BRUTALISMBOT.posts.get bucket: bucket, key: key

  BRUTALISMBOT.twitter.push post, dryrun: dryrun
end

##
# Test function loads
# test
# => { … }
def test(event:nil, context:nil)
  puts "EVENT #{event.to_json}"

  {
    MIN_AGE:  MIN_AGE,
    MIN_TIME: BRUTALISMBOT.posts.max_time,
    MAX_TIME: Time.now.utc.to_i - MIN_AGE,
    DRYRUN:   DRYRUN,
    EVENT:    event.to_json,
  }
end

# --- Slack event handlers

##
# Yield SNS event messages
def each_message(event)
  event.fetch("Records", []).each do |record|
    yield record.dig "Sns", "Message"
  end
end

##
# Handle Slack install event
def slack_install(event:, context:nil)
  puts "EVENT #{event.to_json}"

  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Get current top post
    post = BRUTALISMBOT.reddit.list(:top, limit: 1).first

    # Put Auth on S3
    BRUTALISMBOT.slack.install auth, dryrun: DRYRUN

    # Post to newly installed workspace
    BRUTALISMBOT.slack.push post, auth.webhook_url, dryrun: DRYRUN unless post.nil?
  end
end

##
# Handle Slack uninstall event
def slack_uninstall(event:, context:nil)
  puts "EVENT #{event.to_json}"

  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Remove Auth
    BRUTALISMBOT.slack.uninstall auth, dryrun: DRYRUN
  end
end
