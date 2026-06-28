# frozen_string_literal: true

require 'aws-sdk-dynamodb'

namespace :db do
  task :migrate do
    table = Aws::DynamoDB::Table.new('brutalismbot-green')
    $stderr.write("dynamodb:Scan\n")
    items = table.scan.items.select { |x| x['UpdatedAt'].nil? }
    items.each do |item|
      params = {
        key: item.slice('Id', 'Kind'),
        update_expression: 'REMOVE #UpdatedAt',
        expression_attribute_names: %w[UpdatedAt].to_h { |x| ["##{x}", x] },
      }
      $stderr.write("dynamodb:UpdateItem #{params.to_json}\n")
      table.update_item(**params)
    end
  end
end
