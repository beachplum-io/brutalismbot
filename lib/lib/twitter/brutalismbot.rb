require 'json'
require 'open-uri'

require 'aws-sdk-secretsmanager'
require 'yake/logger'

module Twitter
  class Brutalismbot
    include Yake::Logger

    SECRET_ID = ENV['SECRET_ID'] || 'brutalismbot/twitter'

    def initialize(client:nil)
      @client = client
    end

    def client
      @client ||= begin
        params = { secret_id: SECRET_ID }
        logger.info("GET SECRET #{ params.to_json }")
        secret = OpenStruct.new JSON.parse Aws::SecretsManager::Client.new.get_secret_value(**params).secret_string
        require 'twitter'
        Twitter::REST::Client.new do |config|
          config.access_token        = secret.TWITTER_ACCESS_TOKEN
          config.access_token_secret = secret.TWITTER_ACCESS_TOKEN_SECRET
          config.consumer_key        = secret.TWITTER_CONSUMER_KEY
          config.consumer_secret     = secret.TWITTER_CONSUMER_SECRET
        end
      end
    end

    def post(updates:, count:, **opts)
      updates.each_with_index do |update, i|
        logger.info("PUSH twitter://@brutalismbot [#{i + 1}/#{count}]")
        status = update[:status]
        media  = update[:media].map do |url|
          logger.info("GET #{ url }")
          URI.open(url)
        end
        client.update_with_media(status, media, opts).tap do |res|
          opts[:in_reply_to_status_id] = res.id
          update.update id: res.id
        end
      end

      { updates: updates, count: count }
    end
  end
end
