require 'json'
require 'securerandom'

require 'aws-sdk-eventbridge'
require 'aws-sdk-secretsmanager'
require 'yake/errors'
require 'yake/logger'
require 'yake/support'

module Slack
  class Client
    include Yake::Logger

    EVENT_BUS_NAME = ENV['EVENT_BUS']
    EVENT_SOURCE   = ENV['EVENT_SOURCE']
    SECRET_ID      = ENV['SECRET_ID'] || 'brutalismbot'

    def initialize(event_bus_name:nil, source:nil)
      @event_bus_name = event_bus_name || EVENT_BUS_NAME
      @source         = source         || EVENT_SOURCE
      @eventbridge    = Aws::EventBridge::Client.new
      @secretsmanager = Aws::SecretsManager::Client.new
    end

    def client_id
      secret.SLACK_CLIENT_ID
    end

    def client_secret
      secret.SLACK_CLIENT_SECRET
    end

    def install(event)
      # Handle denials
      query = event['queryStringParameters']
      if query['error']
        logger.error query['error']
        return oauth_error_uri if oauth_error_uri
        raise Yake::Errors::Forbidden, 'OAuth error'
      end

      # Check state
      if state != query['state']
        logger.error "States do not match: #{ state.inspect } != #{ query['state'].inspect }'"
        return oauth_error_uri if oauth_error_uri
        raise Yake::Errors::Forbidden, 'States do not match'
      end

      # Set up OAuth
      payload = {
        code:          query['code'],
        client_id:     client_id,
        client_secret: client_secret,
        redirect_uri:  oauth_redirect_uri,
      }.to_form

      # Execute OAuth and redirect
      uri        = URI 'https://slack.com/api/oauth.v2.access'
      result     = post uri, payload, 'content-type' => 'application/x-www-form-urlencoded'
      app_id     = result['app_id']
      team_id    = result.dig 'team', 'id'
      channel_id = result.dig 'incoming_webhook', 'channel_id'
      location   = secret.SLACK_OAUTH_SUCCESS_URI % [ team_id, channel_id ]

      # Publish event
      publish event.update 'body' => result.to_json

      # Return location
      location
    end

    def install_uri
      "#{ secret.SLACK_OAUTH_INSTALL_URI }&state=#{ state }"
    end

    def oauth_error_uri
      secret.SLACK_OAUTH_ERROR_URI
    end

    def oauth_redirect_uri
      secret.SLACK_OAUTH_REDIRECT_URI
    end

    def post(uri, body = nil, **headers)
      # Normalize headers
      headers.transform_keys!(&:downcase)

      # Execute request
      logger.info "POST #{ uri } #{ body }"
      ssl = uri.scheme == 'https'
      req = Net::HTTP::Post.new(uri, **headers)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: ssl) do |http|
        http.request req, body
      end

      # Log response & return
      begin res.body.to_h_from_json rescue { ok: false } end.tap do |resjson|
        method = resjson['ok'] ? :info : :error
        logger.send method, "RESPONSE [#{ res.code }] #{ res.body }"
      end
    end

    def secret
      @secret ||= begin
        params = { secret_id: SECRET_ID }
        logger.info "SecretsManager:GetSecretValue #{ params.to_json }"
        result = @secretsmanager.get_secret_value(**params)
        OpenStruct.new result.secret_string.to_h_from_json
      end
    end

    def signing_secret
      secret.SLACK_SIGNING_SECRET
    end

    def state
      @state ||= SecureRandom.alphanumeric
    end

    def verify(event)
      # Ensure body is Base64-decoded
      if event['isBase64Encoded']
        body = event['body'].strict_decode64
        event.update('body' => body, 'isBase64Encoded' => false)
      end

      # 403 FORBIDDEN if message is older than 5min
      ts    = event.dig('headers', 'x-slack-request-timestamp')
      delta = Time.now.utc.to_i - ts.to_i
      raise Yake::Errors::Forbidden, 'Request too old' if delta > 5.minutes

      # 403 FORBIDDEN if signatures do not match
      exp  = event.dig('headers', 'x-slack-signature')
      body = event.dig('body')
      data = "v0:#{ ts }:#{ body }"
      hex  = OpenSSL::HMAC.hexdigest('SHA256', signing_secret, data)
      ret  = "v0=#{ hex }"
      raise Yake::Errors::Forbidden, 'Signatures do not match' if ret != exp
    end

    def publish(event)
      detail       = event['body']
      detail_type  = event['routeKey']
      trace_header = event.dig('headers', 'x-amzn-trace-id')

      # Construct entry
      entry = {
        detail:         detail,
        detail_type:    detail_type,
        event_bus_name: @event_bus_name,
        source:         @source,
        trace_header:   trace_header
      }

      # Publish to EventBridge
      params = { entries: [ entry.to_h ] }
      logger.info "EventBridge:PutEvents #{ params.to_json }"
      @eventbridge.put_events(**params).tap do |res|
        raise Yake::Errors::Forbidden, res.to_h.to_json unless res.failed_entry_count.zero?
      end
    end
  end
end
