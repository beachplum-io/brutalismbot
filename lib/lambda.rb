require "logger"

require "brutalismbot"

Aws.config = {logger: Logger.new(STDOUT)}

DRYRUN       = !ENV["DRYRUN"].to_s.empty?
BRUTALISMBOT = Brutalismbot::Client.new

def each_record(event)
  puts "EVENT #{event.to_json}"
  event.fetch("Records", []).each{|record| yield record }
end

def each_message(event)
  each_record event do |record|
    yield record.dig "Sns", "Message"
  end
end

def each_post(event)
  each_record event do |record|
    bucket = URI.unescape record.dig "s3", "bucket", "name"
    prefix = URI.unescape record.dig "s3", "object", "key"
    BRUTALISMBOT.posts.list(bucket: bucket, prefix: prefix).each do |post|
      yield post
    end
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

def pull(event:nil, context:nil)
  items = BRUTALISMBOT.pull(dryrun: DRYRUN)
  {
    count: items.count,
    items: items,
  }
end

def push(event:nil, context:nil)
  each_post event do |post|
    BRUTALISMBOT.push post, dryrun: DRYRUN
  end
end

def push_slack(event:nil, context:nil)
  BRUTALISMBOT.slack.push(event, dryrun: DRYRUN)
end

def push_twitter(event:nil, context:nil)
  BRUTALISMBOT.twitter.push(event, dryrun: DRYRUN)
end

def slack_install(event:nil, context:nil)
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

def slack_uninstall(event:nil, context:nil)
  each_message event do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Slack::Auth.parse message

    # Remove Auth
    BRUTALISMBOT.slack.uninstall auth, dryrun: DRYRUN
  end
end
