module Brutalismbot
  S3_BUCKET = ENV["S3_BUCKET"] || "brutalismbot"
  VERSION   = ENV["VERSION"]   || "v1"

  class Client
    def initialize(bucket:nil, version:nil)
      @bucket  = bucket  || Aws::S3::Bucket.new(name: S3_BUCKET)
      @version = version || VERSION
    end

    def subreddit
      R::Brutalism::Client.new user_agent: "brutalismbot #{@version}"
    end

    def auths
      AuthCollection.new bucket: @bucket,
                         prefix: "oauth/#{@version}/"
    end

    def posts
      PostCollection.new bucket: @bucket,
                         prefix: "posts/#{@version}/"
    end
  end

  class S3Collection
    include Enumerable

    def initialize(bucket:, prefix:)
      @bucket = bucket
      @prefix = prefix
    end

    def each
      puts "GET s3://#{@bucket.name}/#{@prefix}*"
      @bucket.objects(prefix: @prefix).each do |object|
        yield object
      end
    end

    def put(body:, key:, dryrun:nil)
      if dryrun
        puts "PUT DRYRUN s3://#{@bucket.name}/#{key}"
      else
        puts "PUT s3://#{@bucket.name}/#{key}"
        @bucket.put_object key:  key,
                           body: body
      end

      {bucket: @bucket.name, key: key}
    end
  end

  class AuthCollection < S3Collection
    def each
      super do |object|
        yield Slack::OAuth[JSON.parse object.get.body.read]
      end
    end

    def delete(team_id:, dryrun:nil)
      prefix = "#{@prefix}team=#{team_id}/"
      puts "GET s3://#{@bucket.name}/#{prefix}*"
      @bucket.objects(prefix: prefix).map do |object|
        if dryrun
          puts "DELETE DRYRUN s3://#{@bucket.name}/#{object.key}"
          {bucket: @bucket.name, key: object.key}
        else
          puts "DELETE s3://#{@bucket.name}/#{object.key}"
          object.delete
        end
      end
    end

    def put(auth:, dryrun:nil)
      super key:    "#{@prefix}team=#{auth.team_id}/channel=#{auth.channel_id}/oauth.json",
            body:   auth.to_json,
            dryrun: dryrun
    end
  end

  class PostCollection < S3Collection
    def each
      super do |object|
        body = object.get.body.read
        json = JSON.parse body
        yield R::Brutalism::Post[json]
      end
    end

    def get(bucket:, key:)
      @bucket.client.get_object(bucket: bucket, key: key) do |body|
        return R::Brutalism::Post[JSON.parse body]
      end
    end

    def max_time(since:nil)
      since ||= Time.now.utc
      prefix  = prefix_for Time.at(since.to_i).utc

      # Dig for max key
      puts "GET s3://#{@bucket.name}/#{prefix}*"
      until max_key = @bucket.objects(prefix: prefix).map(&:key).max
        # Go up a level in prefix if no keys found
        prefix = prefix.split(/[^\/]+\/\z/).first
        puts "GET s3://#{@bucket.name}/#{prefix}*"
      end

      max_key.match(/(\d+).json\z/).to_a.last.to_i
    end

    def prefix_for(time)
      time  = Time.at(time.to_i).utc
      year  = time.strftime '%Y'
      month = time.strftime '%Y-%m'
      day   = time.strftime '%Y-%m-%d'
      "#{@prefix}year=#{year}/month=#{month}/day=#{day}/"
    end

    def put(post:, dryrun:nil)
      super key:    "#{prefix_for post.created_utc}#{post.created_utc.to_i}.json",
            body:   post.to_json,
            dryrun: dryrun
    end
  end
end
