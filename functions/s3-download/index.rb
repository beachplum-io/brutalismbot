# frozen_string_literal: true

require 'net/http'
require 'tempfile'

require 'aws-sdk-s3'

S3 = Aws::S3::Client.new

def download(item, bucket, prefix, index)
  uri    = URI(item['url'])
  width  = item['width']
  height = item['height']
  key    = File.join(prefix, index.to_s, "#{width}x#{height}", File.basename(uri.path))

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(Net::HTTP::Get.new(uri)) do |response|
      response.value

      Tempfile.create('download', binmode: true) do |body|
        content_type = response['content-type']
        response.read_body { |chunk| body.write(chunk) }
        body.rewind

        S3.put_object(bucket:, key:, body:, content_type:)
      end
    end
  end

  key
end

def handler(event:, **_)
  bucket = event['Bucket']
  key    = event['Key']
  url    = event['Url']
  uri    = URI(url)

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(Net::HTTP::Get.new(uri)) do |response|
      response.value

      Tempfile.create('download', binmode: true) do |body|
        content_type = response['content-type']
        response.read_body { |chunk| body.write(chunk) }
        body.rewind

        S3.put_object(bucket:, key:, body:, content_type:)
      end
    end
  end
end
