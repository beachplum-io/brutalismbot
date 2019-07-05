require "brutalismbot/s3"

DRYRUN    = !ENV["DRYRUN"].to_s.empty?
LAST_SEEN = ENV["LAST_SEEN"]
S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"
S3_PREFIX = ENV["S3_PREFIX"] || "data/v1/"

Brutalismbot.logger = Logger.new(STDOUT, formatter: -> (*x) { "#{x.last}\n" })

BRUTALISMBOT = Brutalismbot::S3::Client.new(
  bucket:         S3_BUCKET,
  prefix:         S3_PREFIX,
  stub_responses: DRYRUN,
)

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
        name   = URI.unescape record.dig("s3", "bucket", "name")
        key    = URI.unescape record.dig("s3", "object", "key")
        bucket = BRUTALISMBOT.bucket name: name
        yield bucket.object(key)
      end
    end
  end
end

def test(event:, context:nil)
  {
    DRYRUN:    DRYRUN,
    S3_BUCKET: S3_BUCKET,
    S3_PREFIX: S3_PREFIX,
  }
end

def authorize(event:, context:nil)
  Event::SNS[event].map do |message|
    # Get OAuth from SNS message
    auth = Brutalismbot::Auth[message]

    # Put Auth on S3
    BRUTALISMBOT.auths.put auth

    # Get current top post
    top_post = BRUTALISMBOT.subreddit.posts(:top, limit: 1).first

    # Post to newly installed workspace
    auth.post body: top_post.to_slack.to_json, dryrun: DRYRUN
  end
end

def cache(event:nil, context:nil)
  # Get latest cached Post fullname
  last_seen = LAST_SEEN || BRUTALISMBOT.posts.last.fullname

  # Cache new posts to S3
  BRUTALISMBOT.posts.pull before: last_seen
end

def mirror(event:, context:nil)
  Event::S3[event].map do |object|
    # Get Post from S3 event
    post = Brutalismbot::Post[JSON.parse object.get.body.read]

    # Post to authorized Slacks
    BRUTALISMBOT.auths.mirror post, dryrun: DRYRUN
  end
end

def uninstall(event:, context:nil)
  Event::SNS[event].map do |message|
    # Get Auth from SNS message
    auth = Brutalismbot::Auth[message]

    # Remove Auth
    BRUTALISMBOT.auths.delete auth
  end
end
