require 'time'

require 'aws-sdk-dynamodb'
require 'yake/logger'

module Aws
  module DynamoDB
    class State
      include Yake::Logger

      def client
        @client ||= Aws::DynamoDB::Client.new
      end

      def table_name
        @table_name ||= ENV.fetch('TABLE_NAME', 'brutalismbot-blue')
      end

      def cursor
        params = {
          table_name:,
          key: { Id: 'r/brutalism', Kind: 'cursor' },
          projection_expression: 'LastUpdate',
        }
        logger.info("dynamodb:GetItem #{params.to_json}")
        last_update = client.get_item(**params).item['LastUpdate']

        Time.parse(last_update)
      end

      def update(queue_size, item = nil)
        if item
          params = { table_name:, item: }
          logger.info("dynamodb:PutItem #{params.to_json}")
          client.put_item(**params)

          params = {
            table_name:,
            key: { Id: 'r/brutalism', Kind: 'cursor' },
            update_expression: 'SET Json=:Json, LastUpdate=:LastUpdate, #Name=:Name, QueueSize=:QueueSize, Title=:Title',
            expression_attribute_names: { '#Name' => 'Name' },
            expression_attribute_values: {
              ':Json'       => item.to_json,
              ':LastUpdate' => item[:LastUpdate],
              ':Name'       => item[:Name],
              ':QueueSize'  => queue_size,
              ':Title'      => item[:Title],
            }
          }
          logger.info("dynamodb:UpdateItem #{params.to_json}")
          client.update_item(**params)
        else
          params = {
            table_name:,
            key: { Id: 'r/brutalism', Kind: 'cursor' },
            update_expression: 'SET QueueSize=:QueueSize',
            expression_attribute_values: { ':QueueSize' => queue_size }
          }
          logger.info("dynamodb:UpdateItem #{params.to_json}")
          client.update_item(**params)
        end
      end
    end
  end
end
