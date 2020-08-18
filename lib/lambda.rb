require "logger"

require "aws-sdk-s3"
require "aws-sdk-secretsmanager"

require "brutalismbot"

DRYRUN         = !ENV["DRYRUN"].to_s.empty?
MIN_AGE        = ENV["MIN_AGE"]&.to_i || 9000
LIMIT          = ENV["LIMIT"]&.to_i
LOG_LEVEL      = ENV["LOG_LEVEL"] || "INFO"
TWITTER_SECRET = ENV["TWITTER_SECRET"] || "brutalismbot/twitter"

LOGGER = Logger.new(STDERR)
LOGGER.level = LOG_LEVEL
Aws.config = {logger: LOGGER}

STS = Aws::STS::Client.new
S3  = Aws::S3::Client.new credentials: STS.config.credentials
S3P = Aws::S3::Presigner.new client: S3
SM  = Aws::SecretsManager::Client.new credentials: STS.config.credentials

ENV.update JSON.parse SM.get_secret_value(secret_id: TWITTER_SECRET).secret_string

BRUTALISMBOT = Brutalismbot::Client.new(
  posts:   Brutalismbot::Posts::Client.new(client: S3),
  reddit:  Brutalismbot::Reddit::Client.new,
  slack:   Brutalismbot::Slack::Client.new(client: S3),
  twitter: Brutalismbot::Twitter::Client.new,
)

# --- State Machine handlers

##
# Pull new posts from /r/brutalism
# Returns [{ bucket: "...", key: "..." }]
def reddit_pull(event:, context:nil)
  puts "EVENT #{event.to_json}"
  event.transform_keys!(&:to_sym)
  event[:dryrun]  ||= DRYRUN
  event[:min_age] ||= MIN_AGE
  event[:limit]   ||= LIMIT
  BRUTALISMBOT.pull(**event)
end

##
# Fetch post body from S3
# Returns { slack: { ... }, twitter: { ... } }
def fetch(event:, context:nil)
  puts "EVENT #{event.to_json}"
  event.transform_keys!(&:to_sym)
  body = JSON.parse S3.get_object(**event).body.read
  post = Brutalismbot::Reddit::Post.new(**body)
  {Slack: post.to_slack, Tweet: post.to_twitter}
end

##
# Get Slack webhooks
# Returns [ "https://hooks.slack.com/services/...", "..." ]
def slack_list(event:, context:nil)
  puts "EVENT #{event.to_json}"
  BRUTALISMBOT.slack.list.map(&:webhook_url)
end

##
# Push post to Slack
def slack_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  event.transform_keys!(&:to_sym)
  event[:dryrun] ||= DRYRUN
  event.tap {|params| BRUTALISMBOT.slack.push(**params).tap(&:value) }
end

##
# Push post to Twitter
def twitter_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  event.transform_keys!(&:to_sym)
  event[:dryrun] ||= DRYRUN
  event.tap {|params| BRUTALISMBOT.twitter.push(**params) }
end

##
# Test function loads
def test(event:, context:nil)
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

    # Put Auth on S3
    BRUTALISMBOT.slack.install auth, dryrun: DRYRUN

    # Get current top post
    post = BRUTALISMBOT.reddit.list(:hot, limit: 1).first

    # Post to newly installed workspace
    event = {body: post.to_slack, webhook_url: auth.webhook_url, dryrun: DRYRUN}
    BRUTALISMBOT.slack.push(**event) unless post.nil?
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
