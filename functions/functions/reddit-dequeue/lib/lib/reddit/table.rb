require 'aws-sdk-dynamodb'
require 'yake/logger'


module Reddit
  class Table
    include Yake::Logger

    attr_reader :name, :client

    def initialize(name: nil, client: nil)
      @name   = name   || ENV['TABLE_NAME'] || 'Brutalismbot'
      @client = client || Aws::DynamoDB::Client.new
    end

    def get_item(**params)
      options = { **params, table_name: @name }
      logger.info("dynamodb:GetItem #{ options.to_json }")
      @client.get_item(**options)
    end
  end
end
