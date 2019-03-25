require "aws-sdk-s3"

S3 = Aws::S3::Client.new

def handler(event:, context:)
  # Log event
  puts "EVENT #{JSON.unparse event}"
end
