# frozen_string_literal

require 'json'

require 'aws-sdk-dynamodb'

module Brutalismbot
  module Table
    def table
      @table ||= Aws::DynamoDB::Table.new('brutalismbot-green')
    end

    def latest
      params = {
        index_name: 'Kind',
        scan_index_forward: false,
        limit: 1,
        key_condition_expression: 'Kind=:Kind',
        projection_expression: 'CreatedAt',
        expression_attribute_values: {':Kind'=>'reddit.post.new'},
      }
      $stderr.write("dynamodb:Query #{params.to_json}\n")
      items = table.query(**params).items
      timestamp = items.map { |x| x['CreatedAt'] }.max
      Time.parse(timestamp)
    end

    def <<(item)
      $stderr.write("dynamodb:PutItem #{item.slice(:Id, :Kind).to_json}\n")
      table.put_item(item:)
    end
  end
end
