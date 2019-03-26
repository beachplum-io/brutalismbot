require "aws-sdk-s3"

DRYRUN    = ENV["DRYRUN"]
S3        = Aws::S3::Client.new
S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"
S3_PREFIX = ENV["S3_PREFIX"] || "oauth/v1/"

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

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"

  # Interate over OAuth SNS records
  event["Records"].each do |record|
    message   = record.dig "Sns", "Message"
    uninstall = JSON.parse message
    team_id   = uninstall.dig "team_id"
    prefix    = "#{S3_PREFIX}team=#{team_id}"

    each_auth(s3: S3, bucket: S3_BUCKET, prefix: prefix) do |key|
      if DRYRUN
        puts "DELETE DRYRUN s3://#{S3_BUCKET}/#{key}"
      else
        puts "DELETE s3://#{S3_BUCKET}/#{key}"
        S3.delete_object bucket: S3_BUCKET, key: key
      end
    end
  end
end
