require "aws-sdk-s3"
require "brutalismbot"

DRYRUN    = !ENV["DRYRUN"].to_s.empty?
MIN_TIME  = !ENV["MIN_TIME"].to_s.empty? && ENV["MIN_TIME"].to_i || nil
S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"
S3_PREFIX = ENV["S3_PREFIX"] || "data/v1/"

BUCKET       = Aws::S3::Bucket.new name: S3_BUCKET
BRUTALISMBOT = Brutalismbot::S3::Client.new bucket: BUCKET, prefix: S3_PREFIX

Brutalismbot.logger = Logger.new STDOUT, formatter: -> (*x) { "#{x.last}\n" }

module Event
  class RecordCollection < Hash
    include Enumerable

    def each
      puts "EVENT #{to_json}"
      dig("Records").each do |record|
        yield record
      end
    end
  end

  class SNS < RecordCollection
    def each
      super do |record|
        yield JSON.parse record.dig("Sns", "Message")
      end
    end
  end

  class S3 < RecordCollection
    def each
      super do |record|
        bucket = URI.unescape record.dig("s3", "bucket", "name")
        key    = URI.unescape record.dig("s3", "object", "key")
        yield Aws::S3::Bucket.new(name: bucket).object(key)
      end
    end
  end
end

def test(event:, context:)
  {
    DRYRUN:    DRYRUN,
    MIN_TIME:  MIN_TIME,
    S3_BUCKET: S3_BUCKET,
    S3_PREFIX: S3_PREFIX,
  }
end

def install(event:, context:)
  Event::SNS[event].map do |message|
    # Get OAuth from SNS message
    auth = Brutalismbot::Auth[message]

    # Put OAuth on S3
    BRUTALISMBOT.auths.put auth: auth, dryrun: DRYRUN

    # Get current top post
    top_post = BRUTALISMBOT.subreddit.posts(:top).first

    # Post to newly installed workspace
    auth.post body: top_post.to_slack.to_json, dryrun: DRYRUN
  end
end

def cache(event:, context:)
  # Get max time of cached posts
  min_time = MIN_TIME || BRUTALISMBOT.posts.max_time

  # Get latest posts on /r/brutalism
  posts = BRUTALISMBOT.subreddit.posts(:new).since time: min_time

  # Cache posts to S3
  BRUTALISMBOT.posts.update posts: posts, dryrun: DRYRUN
end

def mirror(event:, context:)
  Event::S3[event].map do |object|
    # Get post
    json = JSON.parse object.get.body.read
    post = Brutalismbot::Post[json]
    body = post.to_slack.to_json

    # Post to authed Slacks
    BRUTALISMBOT.auths.mirror body: body, dryrun: DRYRUN
  end
end

def uninstall(event:, context:)
  Event::SNS[event].map do |message|
    # Get OAuth from SNS message
    auth = Brutalismbot::Auth[message]

    # Remove all OAuths
    BRUTALISMBOT.auths.remove team: auth.team_id, dryrun: DRYRUN
  end
end
