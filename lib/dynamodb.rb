require 'aws-sdk-dynamodb'
require 'yake'

require_relative 'lib/common'

DYNAMODB = Aws::DynamoDB::Client.new

handler :query do |event|
  params = event.transform_keys { |k| k.snake_case.to_sym }
  DYNAMODB.query(**params).to_h.transform_keys(&:camel_case)
end
