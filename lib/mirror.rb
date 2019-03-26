require "aws-sdk-s3"
require "net/https"

DRYRUN = ENV["DRYRUN"]
S3     = Aws::S3::Client.new

def get_message(record:)
  message = record.dig "Sns", "Message"
  JSON.parse message
end

def get_oauth(s3:, bucket:, key:)
  obj = s3.get_object(bucket: bucket, key: key)
  JSON.parse obj[:body].read
end

def post(url:, body:)
  uri = URI url
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    if DRYRUN
      puts "POST DRYRUN #{uri}"
      OpenStruct.new code: 200, body: '{}'
    else
      puts "POST #{uri}"
      req = Net::HTTP::Post.new uri, 'content-type' => 'application/json'
      req.body = JSON.unparse body
      http.request req
    end
  end
end

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"

  # Iterate over SNS records
  event["Records"].map do |record|

    # Get message
    message = get_message record: record

    # Get OAuth
    bucket = message.dig "bucket"
    key    = message.dig "key"
    oauth  = get_oauth s3: S3, bucket: bucket, key: key

    # Post to Slack
    url  = oauth.dig "incoming_webhook", "url"
    body = message.dig "body"
    post url: url, body: body
  end.map do |res|
    {statusCode: res.code, body: res.body}
  end
end
