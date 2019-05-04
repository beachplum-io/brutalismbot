require "aws-sdk-s3"
require "bundler/setup"
require "brutalismbot"

DRYRUN    = !ENV["DRYRUN"].to_s.empty?
MIN_TIME  = !ENV["MIN_TIME"].to_s.empty? && ENV["MIN_TIME"].to_i || nil
S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"

BUCKET       = Aws::S3::Bucket.new name: S3_BUCKET
BRUTALISMBOT = Brutalismbot::S3::Client.new bucket: BUCKET

def test(event:, context:)
  {
    DRYRUN:    DRYRUN,
    MIN_TIME:  MIN_TIME,
    S3_BUCKET: S3_BUCKET,
  }
end

def install(event:, context:)
  Brutalismbot::Event::SNS[event].map do |message|
    # Get OAuth from SNS message
    oauth = Brutalismbot::OAuth[message]

    # Put OAuth on S3
    BRUTALISMBOT.auths.put auth: oauth, dryrun: DRYRUN

    # Get current top post
    top_post = BRUTALISMBOT.subreddit.top_post

    # Post to newly installed workspace
    oauth.post body: top_post.to_slack.to_json, dryrun: DRYRUN
  end
end

def cache(event:, context:)
  # Get max time of cached posts
  min_time = MIN_TIME || BRUTALISMBOT.posts.max_time

  # Get latest posts to /r/brutalism
  new_posts = BRUTALISMBOT.subreddit.new_posts.after min_time

  # Cache posts to S3
  new_posts.map do |post|
    BRUTALISMBOT.posts.put post: post, dryrun: DRYRUN
  end
end

def mirror(event:, context:)
  Brutalismbot::Event::S3[event].each do |message|
    # Get post
    bucket = Aws::S3::Bucket.new name: message[:bucket]
    object = bucket.object(message[:key]).get.body.read
    post   = R::Brutalism::Post[JSON.parse object]

    # Post to authed Slacks
    BRUTALISMBOT.auths.map do |auth|
      auth.post body:post.to_slack.to_json, dryrun: DRYRUN
    end
  end
end

def uninstall(event:, context:)
  Brutalismbot::Event::SNS[event].each do |message|
    # Get OAuth from SNS message
    oauth = Brutalismbot::OAuth[message]

    # Remove all OAuths
    BRUTALISMBOT.auths.delete team_id: oauth.team_id, dryrun: DRYRUN
  end
end
