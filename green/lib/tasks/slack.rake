# frozen_string_literal: true

require 'aws-sdk-dynamodb'

namespace :slack do
  desc 'Open installation flow'
  task :install do
    sh %{open https://api.brutalismbot.com/slack/install}
  end

  desc 'Sync tokens'
  task :sync do
    source = Aws::DynamoDB::Table.new('brutalismbot-blue')
    target = Aws::DynamoDB::Table.new('brutalismbot-green')
    now    = Time.now.utc.iso8601
    params = {
      index_name: 'Kind',
      key_condition_expression: '#Kind=:Kind',
      expression_attribute_names: { '#Kind' => 'Kind' },
      expression_attribute_values: { ':Kind' => 'slack/token' }
    }
    $stderr.write("dynamodb:Query #{params.to_json}\n")
    source.query(**params).items.each do |item|
      item['Id']         = item['Id'].gsub(/\//, '.')
      item['Kind']       = item['Kind'].gsub(/\//, '.')
      item['CreatedUtc'] = now
      $stderr.write("dynamodb:PutItem #{item.slice('Id', 'Kind').to_json}\n")
      target.put_item(item:)
    end
  end
end
