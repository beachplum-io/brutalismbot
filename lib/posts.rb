require "aws-sdk-s3"
require "net/https"

DRYRUN     = ENV["DRYRUN"]
MIN_TIME   = ENV["MIN_TIME"] && ENV["MIN_TIME"].to_i
S3         = Aws::S3::Client.new
S3_BUCKET  = ENV["S3_BUCKET"]  || "brutalismbot"
S3_PREFIX  = ENV["S3_PREFIX"]  || "posts/v1/"
URL        = ENV["URL"]        || "https://www.reddit.com/r/brutalism/new.json?sort=new"
USER_AGENT = ENV["USER_AGENT"] || "brutalismbot 0.1"

def each_post(s3:, **params)
  keys = [] unless block_given?

  loop do
    # Get S3 page
    puts "GET s3://#{params[:bucket]}/#{params[:prefix]}"
    res = s3.list_objects_v2 **params

    # Yield keys
    res[:contents].each do |obj|
      block_given? ? yield(obj[:key]) : keys << obj[:key]
    end

    # Continue or break
    break unless res[:is_truncated]
    params[:continuation_token] = res[:next_continuation_token]
  end

  keys unless block_given?
end

def get_min_time(s3:, bucket:, prefix:)
  max_key = each_post(s3: s3, bucket: bucket, prefix: prefix).max
  puts "MAX s3://#{bucket}/#{max_key}"

  # Go up a level in prefix if no keys found
  if max_key.nil?
    previous_prefix = prefix.split(/[^\/]+\/\z/).first
    get_min_time s3: s3, bucket: bucket, prefix: previous_prefix

  # Otherwise, return the max time as int
  else
    max_key.split(/\//).last.split(/\.json/).first.to_i
  end
end

def get_posts(url:, user_agent:, min_time:)
  uri = URI url
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    puts "GET #{uri}"
    req   = Net::HTTP::Get.new uri, "user-agent" => user_agent
    res   = http.request req
    body  = JSON.parse res.body
    posts = body.dig "data", "children"
    posts.select do |post|
      created_utc = post.dig "data", "created_utc"
      created_utc > min_time.to_f
    end
  end
end

def cache_post(s3:, bucket:, prefix:, post:)
  utc    = post.dig("data", "created_utc").to_i
  time   = Time.at utc
  prefix = get_prefix prefix: prefix, time: time
  key    = "#{prefix}#{utc}.json"
  body   = JSON.unparse post
  if DRYRUN
    puts "PUT DRYRUN s3://#{bucket}/#{key}"
  else
    puts "PUT s3://#{bucket}/#{key}"
    s3.put_object bucket: S3_BUCKET,
                  key:    key,
                  body:   body
  end
end

def get_prefix(prefix:, time:)
  year  = time.strftime '%Y'
  month = time.strftime '%Y-%m'
  day   = time.strftime '%Y-%m-%d'
  "#{prefix}year=#{year}/month=#{month}/day=#{day}/"
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
