require "aws-sdk-s3"
require "aws-sdk-sns"
require "net/https"

S3            = Aws::S3::Client.new
SNS           = Aws::SNS::Client.new
S3_BUCKET     = ENV["S3_BUCKET"]     || "brutalismbot"
S3_PREFIX     = ENV["S3_PREFIX"]     || "oauth/v1/"
SNS_TOPIC_ARN = ENV["SNS_TOPIC_ARN"] || "arn:aws:sns:us-east-1:556954866954:slack_brutalismbot_mirror"
USER_AGENT    = "brutalismbot 0.1"

class Post < Hash
  def content_type(user_agent:)
    url = self.dig "data", "url"
    uri = URI url
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      puts "HEAD #{uri}"
      req = Net::HTTP::Head.new uri, "user-agent" => user_agent
      res = http.request req
      res.header.content_type
    end
  end

  def to_slack
    url       = self.dig "data", "url"
    title     = self.dig "data", "title"
    permalink = self.dig "data", "permalink"
    {
      blocks: [
        {
          type: "image",
          title: {
            type: "plain_text",
            text: "/r/brutalism",
            emoji: true,
          },
          image_url: url,
          alt_text: title,
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "<https://reddit.com#{permalink}|#{title}>",
            },
          ],
        },
      ],
    }
  end
end

def each_auth(s3:, **params)
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

def get_post(s3:, bucket:, key:)
  obj  = s3.get_object bucket: bucket, key: key
  post = JSON.parse obj[:body].read
  Post[post]
end

def publish(sns:, topic_arn:, **params)
  message = JSON.unparse(params)
  puts "PUBLISH #{JSON.unparse({topic_arn: topic_arn, message: message})}"
  sns.publish topic_arn: topic_arn,
              message:   message
end

def backfill
  each_auth(bucket: S3_BUCKET, prefix: "posts/v1/") do |key|
    event = {Records: [{s3: {bucket: {name: S3_BUCKET}, object: {key: key}}}]}
    handler(event: JSON.parse(JSON.unparse(event)), context: nil)
  end
end

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"

  # Interate over S3 put event records
  event["Records"].each do |record|

    # Get post body / content-type
    bucket       = URI.unescape record.dig("s3", "bucket", "name")
    key          = URI.unescape record.dig("s3", "object", "key")
    post         = get_post s3: S3, bucket: bucket, key: key
    content_type = post.content_type user_agent: USER_AGENT

    # Only pubish if content-type is `image/*`
    if content_type =~ /\Aimage\//

      # Publish SNS message for each OAuth
      each_auth(s3:S3, bucket: S3_BUCKET, prefix: S3_PREFIX) do |key|
        publish sns:       SNS,
                topic_arn: SNS_TOPIC_ARN,
                bucket:    S3_BUCKET,
                key:       key,
                body:      post.to_slack
      end

    # Otherwise raise TypeError
    else
      error = "s3://#{bucket}/#{key}[#{content_type}]"
      puts "ERROR #{error}"
      raise TypeError.new error
    end
  end
end
