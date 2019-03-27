require "aws-sdk-s3"
require "net/https"
require_relative "./util"

DRYRUN     = ENV["DRYRUN"]
MIN_TIME   = ENV["MIN_TIME"] && ENV["MIN_TIME"].to_i
S3         = Aws::S3::Client.new
S3_BUCKET  = ENV["S3_BUCKET"]  || "brutalismbot"
S3_PREFIX  = ENV["S3_PREFIX"]  || "posts/v1/"
URL        = ENV["URL"]        || "https://www.reddit.com/r/brutalism/new.json?sort=new"
USER_AGENT = ENV["USER_AGENT"] || "brutalismbot 0.1"

def get_prefix(prefix:, time:)
  year  = time.strftime '%Y'
  month = time.strftime '%Y-%m'
  day   = time.strftime '%Y-%m-%d'
  "#{prefix}year=#{year}/month=#{month}/day=#{day}/"
end

def get_min_time(s3:, bucket:, prefix:)
  max_key = s3_keys(s3: s3, bucket: bucket, prefix: prefix).map(&:key).max

  # Go up a level in prefix if no keys found
  if max_key.nil?
    previous_prefix = prefix.split(/[^\/]+\/\z/).first
    get_min_time s3: s3, bucket: bucket, prefix: previous_prefix

  # Otherwise, return the max time as int
  else
    max_key.match(/(\d+).json\z/).to_a.last.to_i
  end
end

def get_posts(url:, user_agent:, min_time:)
  res   = request_json url: url, user_agent: user_agent, method: Net::HTTP::Get
  posts = res.dig "data", "children"
  posts.select do |post|
    created_utc = post.dig "data", "created_utc"
    created_utc > min_time.to_f
  end
end

def cache_post(s3:, bucket:, prefix:, post:)
  utc    = post.dig("data", "created_utc").to_i
  time   = Time.at(utc).utc
  prefix = get_prefix prefix: prefix, time: time
  key    = "#{prefix}#{utc}.json"
  body   = JSON.unparse post
  if DRYRUN
    puts "PUT DRYRUN s3://#{bucket}/#{key}"
    {bucket: bucket, key: key}
  else
    puts "PUT s3://#{bucket}/#{key}"
    s3.put_object bucket: S3_BUCKET,
                  key:    key,
                  body:   body
  end
end

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"

  # Get prefix
  prefix = get_prefix prefix: S3_PREFIX,
                      time:   Time.now.utc

  # Get max time of cached posts
  min_time = MIN_TIME || get_min_time(s3: S3, bucket: S3_BUCKET, prefix: prefix)

  # Get latest posts to /r/brutalism
  posts = get_posts url:        URL,
                    user_agent: USER_AGENT,
                    min_time:   min_time

  # Cache posts to S3
  posts.map do |post|

    cache_post s3:     S3,
               bucket: S3_BUCKET,
               prefix: S3_PREFIX,
               post:   post

  end.map &:to_h
end
