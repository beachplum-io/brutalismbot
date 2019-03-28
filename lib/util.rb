class Post < Hash
  def content_type(user_agent:)
    url = self.dig "data", "url"
    res = request_url url: url, user_agent: user_agent, method: Net::HTTP::Head
    res.header.content_type
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

def s3_keys(s3:, **params)
  keys = []

  loop do
    # Get S3 page
    puts "GET s3://#{params[:bucket]}/#{params[:prefix]}"
    res = s3.list_objects_v2 **params

    # Yield keys
    keys += res[:contents].map{|x| block_given? ? yield(x) : x }

    # Next page or break
    break unless res[:is_truncated]
    params[:continuation_token] = res[:next_continuation_token]
  end

  keys
end

def request_url(url:, user_agent:, method:)
  uri = URI url
  ssl = uri.scheme == "https"
  puts "GET #{uri}"
  Net::HTTP.start(uri.host, uri.port, use_ssl: ssl) do |http|
    http.request method.new(uri, "user-agent" => user_agent)
  end
end

def request_json(url:, user_agent:, method:)
  res = request_url url: url, user_agent: user_agent, method: method
  JSON.parse res.body
end
