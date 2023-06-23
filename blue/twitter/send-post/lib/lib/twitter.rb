require 'json'

require 'aws-sdk-ssm'
require 'twurl'
require 'yake/logger'

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
      media_ids = upload(*media).map do |upload|
        upload['media_id_string']
      end

      # Send tweet!
      data[:text]  = text || ''
      data[:media] = { media_ids: media_ids } if media_ids.any?
      options = Twurl::Options.new(
        request_method:  'post',
        host:            'api.twitter.com',
        path:            '/2/tweets',
        headers:         { 'content-type' => 'application/json' },
        data:            { data.to_json => nil },
      )
      logger.info "POST #{File.join api_client.consumer.options[:site], options.path}"
      result = api_client.perform_request_from_options(options).read_body.to_h_from_json

      # Initialize data for next reply
      tweet_id = result.dig('data', 'id')
      data[:reply] = { in_reply_to_tweet_id: tweet_id }

      result['data']
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
    logger.error("COULD NOT DOWNLOAD MEDIA")
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
    images.map do |image|
      Tempfile.open do |tempfile|
        tempfile.write(image.body)
        tempfile.rewind

        options = Twurl::Options.new(
          request_method:  'post',
          host:            'upload.twitter.com',
          path:            '/1.1/media/upload.json',
          headers:         {},
          data:            {},
          upload:          { 'file' => [ tempfile.path ], 'filefield' => 'media' },
        )
        logger.info "POST #{ File.join upload_client.consumer.options[:site], options.path }"
        result = upload_client.perform_request_from_options options
        result.read_body.to_h_from_json rescue raise result.message
      end
    end
  rescue => err
    logger.error("COULD NOT UPLOAD MEDIA")
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

  def client(host = nil)
    Twurl.options.host = host || 'api.twitter.com'
    Twurl::OAuthClient.load_from_options Twurl::Options.new(
      command:         'request',
      username:        username,
      consumer_key:    consumer_key,
      consumer_secret: consumer_secret,
      access_token:    access_token,
      token_secret:    token_secret,
    )
  end

  def api_client
    @api_client ||= client 'api.twitter.com'
  end

  def upload_client
    @upload_client ||= client 'upload.twitter.com'
  end

  def consumer_key
    params.TWITTER_CONSUMER_KEY
  end

  def consumer_secret
    params.TWITTER_CONSUMER_SECRET
  end

  def access_token
    params.TWITTER_ACCESS_TOKEN
  end

  def token_secret
    params.TWITTER_ACCESS_TOKEN_SECRET
  end

  def username
    params.TWITTER_USERNAME
  end
end
