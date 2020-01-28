require "logger"

require "brutalismbot"

Aws.config = {logger: Logger.new(STDOUT)}

DRYRUN       = !ENV["DRYRUN"].to_s.empty?
LIMIT        = ENV["LIMIT"]&.to_i
BRUTALISMBOT = Brutalismbot::Client.new
S3           = Aws::S3::Client.new

def each_record(event)
  puts "EVENT #{event.to_json}"
  event.fetch("Records", []).each{|record| yield record }
end

def each_message(event)
  each_record event do |record|
    yield record.dig "Sns", "Message"
  end
end

def reddit_pull(event:nil, context:nil)
  BRUTALISMBOT.pull limit: LIMIT, dryrun: DRYRUN
end

def s3_fetch(event:, context:nil)
  puts "EVENT #{event.to_json}"
  options = event.transform_keys(&:to_sym)
  response = S3.get_object(**options)
  JSON.parse response.body.read
end

def slack_install(event:, context:nil)
  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Put Auth on S3
    BRUTALISMBOT.slack.install auth, dryrun: DRYRUN

    # Get current top post
    post = BRUTALISMBOT.reddit.list(:top, limit: 1).first

    # Post to newly installed workspace
    auth.push post, dryrun: DRYRUN
  end
end

def slack_list(event:nil, context:nil)
  BRUTALISMBOT.slack.keys.map{|x| {bucket: x.bucket_name, key: x.key} }
end

def slack_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  post = Brutalismbot::Reddit::Post.new event["Post"]
  auth = Brutalismbot::Slack::Auth.new event["Slack"]
  auth.push post, dryrun: DRYRUN
end

def slack_uninstall(event:, context:nil)
  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Remove Auth
    BRUTALISMBOT.slack.uninstall auth, dryrun: DRYRUN
  end
end

def test(event:nil, context:nil)
  {
    LAG_TIME: BRUTALISMBOT.lag_time,
    MIN_TIME: BRUTALISMBOT.posts.max_time,
    MAX_TIME: Time.now.utc.to_i - BRUTALISMBOT.lag_time,
    DRYRUN:   DRYRUN,
    EVENT:    event.to_json,
  }
end

def twitter_push(event:, context:nil)
  puts "EVENT #{event.to_json}"
  post = Brutalismbot::Reddit::Post.new event["Post"]
  BRUTALISMBOT.twitter.push post, dryrun: DRYRUN
end
