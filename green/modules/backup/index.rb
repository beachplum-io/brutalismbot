require 'net/http'

require 'aws-sdk-s3'

# {
#   "Prefix": "r/brutalism/t3_104zn71/0/108x81/",
#   "Url": "https://preview.redd.it/c2cufog6zhaa1.jpg?width=108&crop=smart&auto=webp&v=enabled&s=395b671bfd853415e4ed23de5205d5bf8fc11c18"
# }


S3 = Aws::S3::Client.new

def backup(event:, **_)
  # Download
  uri = URI(event['Url'])
  res = Net::HTTP.get_response(uri)
  return unless res.code == '200'

  # Upload
  body         = res.body
  content_type = res['content-type']
  bucket       = event['Bucket']
  key          = File.join(event['Prefix'], uri.path)
  S3.put_object(bucket:, key:, body:, content_type:)

  # Return Bucket/Key
  { Bucket: bucket, Key: key }
end
