require 'net/http'

require 'aws-sdk-ssm'
require 'yake/logger'
require 'yake/support'

require_relative 'post'

module Reddit
  class Brutalism
    include Enumerable
    include Yake::Logger

    PARAM_PATH ||= ENV['PARAM_PATH']
    USER_AGENT ||= ENV['USER_AGENT'] || 'Brutalismbot'

    attr_reader :resource, :user_agent, :path

    def initialize(resource = nil, path = nil)
      @resource = resource || :new
      @path     = path     || PARAM_PATH
      @ssm      = Aws::SSM::Client.new
    end

    def client_id     = params.CLIENT_ID
    def client_secret = params.CLIENT_SECRET
    def refresh_token = params.REFRESH_TOKEN
    def user_agent    = params.USER_AGENT

    def each
      uri = URI("https://oauth.reddit.com/r/brutalism/#{ resource }.json?raw_json=1")

      headers = {
        'authorization' => authorization,
        'user-agent'    => user_agent
      }

      req = Net::HTTP::Get.new(uri, **headers)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        logger.info("GET #{ uri }")
        http.request(req)
      end

      res.body.to_h_from_json.symbolize_names.dig(:data, :children).each do |child|
        post = Post.new child[:data]
        yield post if post.media_urls.any?
      end
    end

    def all
      to_a
    end

    def latest(start)
      after(start).reject(&:is_self?).sort_by(&:created_utc)
    end

    def after(start)
      select { |post| post.created_utc > start }
    end

    def between(start, stop)
      select { |post| post.created_utc > start && post.created_utc < stop }
    end

    def before(stop)
      select { |post| post.created_utc < stop }
    end

    class << self
      def hot(**headers)
        new(:hot, **headers)
      end

      def top(**headers)
        new(:top, **headers)
      end
    end

    private

    def params
      @params ||= fetch_params
    end

    def authorization
      @authorization ||= fetch_authorization
    end

    def fetch_authorization
      auth = "#{ client_id }:#{ client_secret }".strict_encode64
      uri  = URI('https://www.reddit.com/api/v1/access_token')

      headers = {
        'authorization' => "Basic #{ auth }",
        'content-type'  => 'application/x-www-form-urlencoded',
        'user-agent'    => user_agent,
      }

      body = {
        'grant_type'    => 'refresh_token',
        'refresh_token' => refresh_token,
      }.to_form

      req = Net::HTTP::Post.new(uri, **headers)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        logger.info("POST #{ uri }")
        http.request(req, body).body.to_h_from_json
      end

      "Bearer #{ res['access_token'] }"
    end

    def fetch_params
      params = { path: @path, with_decryption: true }
      logger.info "SSM:GetParametersByPath #{params.to_json}"
      result = @ssm.get_parameters_by_path(**params).map(&:parameters).flatten.map do |param|
        { File.basename(param.name) => param.value }
      end.reduce(&:merge)

      OpenStruct.new(result)
    end
  end
end
