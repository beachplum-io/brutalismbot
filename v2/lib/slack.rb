require "yake"

require_relative "slack/auth"
require_relative "slack/table"

TABLE = Slack::Table.new

handler :auths do
  TABLE.list_auths
end

handler :transform do |event|
  media = event["Media"]
  title = event["Title"]
  perma = event["Permalink"]

  media_blocks = media.map do |image_url|
    {
      type: "image",
      title: { type: "plain_text", text: "/r/brutalism", emoji: true },
      image_url: image_url,
      alt_text: title,
    }
  end

  context_blocks = [
    {
      type: "context",
      elements: [ { type: "mrkdwn", text: "<https://www.reddit.com#{ perma }|#{ title }>" } ],
    }
  ]

  { text: title, blocks: media_blocks + context_blocks }
end

handler :migrate do
  require "aws-sdk-s3"
  bucket = Aws::S3::Bucket.new name:"brutalismbot"
  auths  = bucket.objects(prefix:"data/v1/auths/").map do |obj|
    Yake.logger.info "GET s3://#{ bucket.name }/#{ obj.key }"
    Slack::Auth.new JSON.parse obj.get.body.read
  end
  TABLE.put_auths(*auths)
end
