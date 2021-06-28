require "yake"

require_relative "lib/common"

DYNAMODB = Aws::DynamoDB::Client.new

handler :query do |event|
  params = event.transform_keys(&:snake_case)
  DYNAMODB.query(**params).to_h.transform_keys(&:camel_case)
end
