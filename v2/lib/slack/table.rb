require "aws-sdk-dynamodb"
reqiure "yake/logger"

module Slack
  class Table
    include Yake::Logger

    def initialize(name = nil, client = nil)
      @name   = name   || ENV["DYNAMODB_TABLE"]
      @client = client || Aws::DynamoDB::Client.new
    end

    def list_auths(**options)

    end
  end
end
