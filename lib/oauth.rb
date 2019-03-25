require "aws-sdk-s3"

S3        = Aws::S3::Client.new
S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"
S3_PREFIX = ENV["S3_PREFIX"] || "oauth/v1/"

def get_key(prefix:, body:)
  message    = JSON.parse body
  team_id    = message.dig "team_id"
  channel_id = message.dig "incoming_webhook", "channel_id"
  "#{prefix}team=#{team_id}/channel=#{channel_id}/oauth.json"
end

def put_key(s3:, bucket:, key:, body:)
  puts "PUT s3://#{S3_BUCKET}/#{key}"
  s3.put_object bucket: S3_BUCKET,
                key:    key,
                body:   body
end

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"

  # Interate over OAuth SNS records
  event["Records"].map do |record|

    # Get S3 Key
    body = record.dig "Sns", "Message"
    key  = get_key prefix: S3_PREFIX, body: body

    # Put OAuth event on S3
    put_key s3: S3, bucket: S3_BUCKET, key: key, body: body

  end.map(&:to_h)
end
