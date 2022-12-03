require 'json'
require 'open-uri'

require 'aws-sdk-secretsmanager'
require 'twurl'
require 'yake/logger'

module Twitter
  class Brutalismbot
    include Yake::Logger

    SECRET_ID = ENV['SECRET_ID'] || 'brutalismbot'

    def initialize(secret_id:nil)
      @secret_id      = secret_id || SECRET_ID
      @secretsmanager = Aws::SecretsManager::Client.new
    end

    def secret
      @secret ||= begin
        params = { secret_id: @secret_id }
        logger.info "GET SECRET #{ params.to_json }"
        result = @secretsmanager.get_secret_value(**params)
        OpenStruct.new JSON.parse result.secret_string
      end
    end

    def tweet(**data)
      options = Twurl::Options.new(
        request_method:  'post',
        host:            'api.twitter.com',
        path:            '/2/tweets',
        headers:         { 'content-type' => 'application/json' },
        data:            { data.to_json => nil },
      )
      logger.info "POST #{ File.join twitter_api_client.consumer.options[:site], options.path }"
      result = twitter_api_client.perform_request_from_options options
      JSON.parse result.read_body
    end

    def upload(url)
      logger.info "GET #{ url }"
      options = Twurl::Options.new(
        request_method:  'post',
        host:            'upload.twitter.com',
        path:            '/1.1/media/upload.json',
        headers:         {},
        data:            {},
        upload:          { 'file' => [ URI.open(url).path ], 'filefield' => 'media' },
      )
      logger.info "POST #{ File.join twitter_upload_client.consumer.options[:site], options.path }"
      result = twitter_upload_client.perform_request_from_options options
      JSON.parse result.read_body
    end

    def post(updates:nil, count:nil, **data)
      updates.each_with_index do |update, i|
        logger.info "PUSH twitter://@brutalismbot [#{i + 1}/#{count}]"

        # Upload media for tweet
        media     = update[:media].map { |url| upload url }
        media_ids = media.map { |x| x['media_id_string'] }

        # Send tweet
        text = update[:status] || ""
        data.update 'text' => text, 'media' => { 'media_ids' => media_ids }
        result = tweet(**data)

        # Initialize data for next reply
        tweet_id = result.dig('data', 'id')
        data.update 'reply' => { 'in_reply_to_tweet_id' => tweet_id }

        # Add tweet ID to update
        update.update id: tweet_id
      end

      { updates: updates, count: count }
    end

    def twitter_client(host = nil)
      Twurl.options.host = host || 'api.twitter.com'
      Twurl::OAuthClient.load_from_options Twurl::Options.new(
        command:         'request',
        username:        twitter_username,
        consumer_key:    twitter_consumer_key,
        consumer_secret: twitter_consumer_secret,
        access_token:    twitter_access_token,
        token_secret:    twitter_token_secret,
      )
    end

    def twitter_api_client
      @api_client ||= twitter_client 'api.twitter.com'
    end

    def twitter_upload_client
      @upload_client ||= twitter_client 'upload.twitter.com'
    end

    def twitter_consumer_key
      secret.TWITTER_CONSUMER_KEY
    end

    def twitter_consumer_secret
      secret.TWITTER_CONSUMER_SECRET
    end

    def twitter_access_token
      secret.TWITTER_ACCESS_TOKEN
    end

    def twitter_token_secret
      secret.TWITTER_ACCESS_TOKEN_SECRET
    end

    def twitter_username
      secret.TWITTER_USERNAME
    end
  end
end
