require "aws-sdk-dynamodb"
require "yake/logger"

module Slack
  class Table
    include Yake::Logger

    attr_reader :client, :name

    def initialize(name = nil, client = nil)
      @name   = name   || ENV["DYNAMODB_TABLE"] || "Brutalismbot"
      @client = client || Aws::DynamoDB::Client.new
    end

    def list_auths(**options)
      params = {
        table_name: @name,
        index_name: "SlackTeam",
      }
      logger.info "QUERY #{ params.to_json }"
      @client.query(**params)
    end

    def put_auths(*auths)
      auths.map do |auth|
        {
          put: {
            table_name: @name,
            item: {
              GUID:         "#{ auth.team_id }/#{ auth.channel_id }",
              SORT:         "SLACK/AUTH",
              TEAM_ID:      auth.team_id,
              TEAM_NAME:    auth.team_name,
              CHANNEL_ID:   auth.channel_id,
              CHANNEL_NAME: auth.channel_name,
              WEBHOOK_URL:  auth.url.to_s,
              JSON:         auth.to_json,
            }.compact
          }
        }
      end.each_slice(25) do |page|
        page.each { |x| logger.info "PUT #{ x.dig(:put, :item).slice :GUID, :SORT }"}
        @client.transact_write_items transact_items: page
      end
    end
  end
end
