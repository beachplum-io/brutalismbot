require "logger"

require "brutalismbot"

Aws.config = {logger: Logger.new(STDOUT)}

DRYRUN  = !ENV["DRYRUN"].to_s.empty?
MIN_AGE = ENV["MIN_AGE"]&.to_i || 9000
LIMIT   = ENV["LIMIT"]&.to_i

BRUTALISMBOT = Brutalismbot::Client.new
S3           = Aws::S3::Client.new

def each_message(event)
  event.fetch("Records", []).each do |record|
    yield record.dig "Sns", "Message"
  end
end

def fetch(event:, context:nil)
  puts "EVENT #{event.to_json}"
  options  = event.transform_keys(&:to_sym)
  response = S3.get_object(**options)
  JSON.parse response.body.read
end

def reddit_pull(event:, context:nil)
  puts "EVENT #{event.to_json}"
  dryrun  = event.fetch("Dryrun", DRYRUN)
  min_age = event.fetch("Lag",    MIN_AGE)
  limit   = event.fetch("Limit",  LIMIT)
  BRUTALISMBOT.pull min_age: min_age, limit: limit, dryrun: dryrun
end

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
    auth.push post, dryrun: DRYRUN unless post.nil?
  end
end

def slack_list(event:, context:nil)
  puts "EVENT #{event.to_json}"
  BRUTALISMBOT.slack.keys.map{|x| {bucket: x.bucket_name, key: x.key} }
end

def slack_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  dryrun = event.fetch("Dryrun", DRYRUN)
  auth   = BRUTALISMBOT.slack.get(**event["Slack"].transform_keys(&:to_sym))
  post   = Brutalismbot::Reddit::Post.new(**event["Post"])
  post.mime_type = event["Content-Type"]
  auth.push post, dryrun: dryrun
  post.to_slack
end

def slack_uninstall(event:, context:nil)
  puts "EVENT #{event.to_json}"
  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Remove Auth
    BRUTALISMBOT.slack.uninstall auth, dryrun: DRYRUN
  end
end

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

def twitter_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  dryrun = event.fetch("Dryrun", DRYRUN)
  post   = Brutalismbot::Reddit::Post.new(**event["Post"])
  post.mime_type = event["Content-Type"]
  BRUTALISMBOT.twitter.push post, dryrun: dryrun
  {status: post.to_twitter, media: post.url}
end
