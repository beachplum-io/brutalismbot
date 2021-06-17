module Slack
  class Auth < OpenStruct
    def initialize(...)
      super
      yield self if block_given?
    end

    def inspect
      "#<#{ self.class } team_id: #{ team_id }, channel_id: #{ channel_id }>"
    end

    def to_json
      to_h.to_json
    end

    def key
      File.join(team_id, channel_id)
    end

    def channel_id
      dig("incoming_webhook", "channel_id")
    end

    def channel_name
      dig("incoming_webhook", "channel")
    end

    def team_id
      dig("team", "id") || dig("team_id")
    end

    def team_name
      dig("team", "name") || dig("team_name")
    end

    def url
      URI(dig "incoming_webhook", "url")
    end
  end
end
