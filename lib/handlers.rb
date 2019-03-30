require "aws-sdk-s3"
require_relative "./brutalismbot"
require_relative "./event"
require_relative "./r"
require_relative "./slack"

DRYRUN     = ENV["DRYRUN"]
MIN_TIME   = ENV["MIN_TIME"] && ENV["MIN_TIME"].to_i
S3_BUCKET  = ENV["S3_BUCKET"]

BUCKET       = Aws::S3::Bucket.new name: S3_BUCKET
BRUTALISMBOT = Brutalismbot::Client.new bucket: BUCKET

def install(event:, context:)
  Event::SNS[event].map do |message|
    # Get OAuth from SNS message
    oauth = Slack::OAuth[message]

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
  Event::S3[event].each do |message|
    # Get post
    post = BRUTALISMBOT.posts.get **message

    # Post to authed Slacks
    BRUTALISMBOT.auths.map do |auth|
      auth.post body:post.to_slack.to_json, dryrun: DRYRUN
    end
  end
end

def uninstall(event:, context:)
  Event::SNS[event].each do |message|
    # Get OAuth from SNS message
    oauth = Slack::OAuth[message]

    # Remove all OAuths
    BRUTALISMBOT.auths.delete team_id: oauth.team_id, dryrun: DRYRUN
  end
end
