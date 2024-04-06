require 'json'

require 'aws-sdk-ssm'
require 'yake/logger'

class Bluesky
  include Yake::Logger

  ENDPOINT   ||= 'https://bsky.social/xrpc'
  MAX_TEXT   ||= 300
  MAX_IMAGE  ||= 1000000
  PARAM_PATH ||= ENV['PARAM_PATH']
  R_BRUTALISM ||= 'r/brutalism'

  def initialize(path:nil)
    @path = path || PARAM_PATH
    @ssm  = Aws::SSM::Client.new
  end

  def thread(text:, link:, media:)
    # Get alt
    alt = text.length >= MAX_TEXT ? "#{text[...MAX_TEXT]}…" : "#{text}"

    # Get text
    max   = MAX_TEXT - R_BRUTALISM.length
    text  = text.length < max ? "#{text} " : "#{text[...max]}… "
    text << R_BRUTALISM

    # Zip media & text
    size  = (media.count % 4).between?(1, 2) ? 3 : 4
    posts = media.each_slice(size).zip([text])

    # Post thread
    root = parent = nil
    posts.each_with_index.map do |post, i|
      logger.info "THREAD @#{username} [#{i + 1}/#{posts.count}]"

      # Expand post
      media, text = post

      # Get images
      images = upload(*media).map do |blob|
        { image: blob, alt: '' }
      end

      # Compose record
      embed = {
        :'$type' => 'app.bsky.embed.images',
        :images  => images,
      }
      facets = [{
        :features => [{
          :'$type' => 'app.bsky.richtext.facet#link',
          :uri     => link,
        }],
        :index => {
          :byteStart => text.bytes.length - '/r/brutalism'.bytes.length,
          :byteEnd   => text.bytes.length,
        }
      }] unless text.nil?
      reply = {
        :parent => parent,
        :root   => root,
      } unless root.nil? || parent.nil?
      record = {
        :'$type'   => 'app.bsky.feed.post',
        :createdAt => UTC.now.iso8601,
        :embed     => embed,
        :facets    => facets,
        :reply     => reply,
        :text      => text || '',
      }.compact
      data = {
        :collection => 'app.bsky.feed.post',
        :record     => record,
        :repo       => session.did,
      }

      # Send post
      url = File.join ENDPOINT, 'com.atproto.repo.createRecord'
      uri = URI url
      hed = { 'authorization' => "Bearer #{session.accessJwt}", 'content-type' => 'application/json' }
      req = Net::HTTP::Post.new(uri.path, **hed)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(req, data.to_json)
      end
      ref = res.body.to_h_from_json

      # Set root/parent for next iteration
      root ||= ref
      parent = ref

      # Yield post data
      { data: data, ref: ref }
    end
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

  def session
    @session ||= begin
      url  = File.join ENDPOINT, 'com.atproto.server.createSession'
      uri  = URI url
      body =
      req  = Net::HTTP::Post.new(uri.path, 'content-type' => 'application/json')
      res  = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        logger.info("POST #{uri}")
        http.request(req, { identifier: username, password: password }.to_json)
      end

      OpenStruct.new(res.body.to_h_from_json)
    end
  end

  def username
    params.BLUESKY_USERNAME
  end

  def password
    params.BLUESKY_PASSWORD
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

    # Prepare request
    url = File.join ENDPOINT, 'com.atproto.repo.uploadBlob'
    uri = URI url
    hed = { 'authorization' => "Bearer #{session.accessJwt}" }

    # Upload images
    images.map do |image|
      req = Net::HTTP::Post.new(uri.path, 'content-type' => image['content-type'], **hed)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        logger.info "POST #{url}"
        http.request(req, image.body)
      end

      res.body.to_h_from_json['blob']
    end
  rescue => err
    logger.error("COULD NOT UPLOAD MEDIA")
    logger.error(err)
    raise err
  end
end
