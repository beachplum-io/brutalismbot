require "json"

require "aws-sdk-dynamodb"
require "yake"

TABLE = Aws::DynamoDB::Table.new name: ENV["TABLE_NAME"] || "Brutalismbot"

class String
  def camel_case() split(/_/).map(&:capitalize).join end
  def snake_case() gsub(/([a-z])([A-Z])/, '\1_\2').downcase end
end

class Symbol
  def camel_case() to_s.camel_case.to_sym end
  def snake_case() to_s.snake_case.to_sym end
end

handler :query do |event|
  params = event.transform_keys(&:snake_case)
  TABLE.query(**params).to_h.transform_keys(&:camel_case)
end
