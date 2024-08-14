require 'json'

require 'aws-sdk-ssm'
require 'x'
require 'x/media_uploader'
require 'yake/logger'

class TwitterError < StandardError; end

class Twitter
  include Yake::Logger

  MAX_STATUS ||= 280
  MAX_IMAGE  ||= 5242880
  PARAM_PATH ||= ENV['PARAM_PATH']

  def initialize(path:nil)
    @path = path || PARAM_PATH
    @ssm  = Aws::SSM::Client.new
  end

  def thread(text:, link:, media:)
    # Get text
    max   = MAX_STATUS - link.length
    text  = text.length < max ? "#{text} " : "#{text[...max]}… "
    text << link

    # Zip media & status
    size   = (media.count % 4).between?(1, 2) ? 3 : 4
    tweets = media.each_slice(size).zip([text])

    # Post thread
    data = {}
    tweets.each_with_index.map do |tweet, i|
      logger.info "THREAD #{username} [#{i + 1}/#{tweets.count}]"

      # Expand tweet
      media, text = tweet

      # Upload media
      media_ids = upload(*media).map { |u| u['media_id_string'] }
      media = { media_ids: } if media_ids.any?

      # Send tweet!
      data[:text]  = text || ''
      data[:media] = { media_ids: } if media_ids.any?
      logger.info "POST #{ data.to_json }"
      tweet = client.post('tweets', data.to_json)

      raise TwitterError, tweet.to_json unless tweet['data']

      # Initialize data for next reply
      in_reply_to_tweet_id = tweet.dig('data', 'id')
      data[:reply] = { in_reply_to_tweet_id: }

      tweet['data']
    end
  end

  def fetch(url)
    uri = URI url
    hed = { 'user-agent' => 'Brutalismbot' }
    req = Net::HTTP::Get.new(url, **hed)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      logger.info "GET #{url}"
      http.request(req)
    end

    res
  rescue => err
    logger.error('COULD NOT DOWNLOAD MEDIA')
    logger.error(err)
    raise err
  end

  def upload(*media)
    # Fetch images
    images = media.map do |sizes|
      Enumerator.new do |enum|
        sizes.map do |size|
          url = size['u']
          img = fetch(url)
          enum.yield(img) if img['content-length'].to_i <= MAX_IMAGE
        end
      end.first
    end

    # Upload images
    images.each_with_index.map do |image, i|
      Tempfile.open('twitter-', '/tmp') do |tempfile|
        tempfile.write(image.body)
        tempfile.rewind

        file_path      = tempfile.path
        media_category = 'tweet_image'

        logger.info "UPLOAD #{file_path} [#{i + 1}/#{images.count}]"
        X::MediaUploader.upload(client:, file_path:, media_category:)
      end
    end
  rescue => err
    logger.error('COULD NOT UPLOAD MEDIA')
    logger.error(err)
    raise err
  end

  def params
    @params ||= begin
      params = { path: @path, with_decryption: true }
      logger.info "SSM:GetParametersByPath #{params.to_json}"
      result = @ssm.get_parameters_by_path(**params).map(&:parameters).flatten.map do |param|
        { File.basename(param.name) => param.value }
      end.reduce(&:merge)
      OpenStruct.new(result)
    end
  end

  def client
    @client ||= X::Client.new(base_url:, api_key:, api_key_secret:, access_token:, access_token_secret:)
  end

  def base_url            = 'https://api.twitter.com/2/'
  def api_key             = params.TWITTER_CONSUMER_KEY
  def api_key_secret      = params.TWITTER_CONSUMER_SECRET
  def access_token        = params.TWITTER_ACCESS_TOKEN
  def access_token_secret = params.TWITTER_ACCESS_TOKEN_SECRET
  def username            = params.TWITTER_USERNAME
end
