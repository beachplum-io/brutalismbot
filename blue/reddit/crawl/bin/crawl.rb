#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'time'

require 'aws-sdk-dynamodb'
require 'yake/support'

require_relative '../lib/post'

DYNAMODB   ||= Aws::DynamoDB::Client.new
USER_AGENT ||= 'Brutalismbot'
ENDPOINT   ||= 'https://www.reddit.com/r/brutalism/new.json'

def get_page(**params)
  qry = { raw_json: 1, **params }
  uri = URI("#{ ENDPOINT }?#{ qry.to_form }")
  req = Net::HTTP::Get.new(uri, 'user-agent' => USER_AGENT)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    $stderr.write("GET #{uri}\n")
    http.request(req).body.to_h_from_json
  end
end

def get_items
  after = nil
  is_self = ->(i) { i.dig('data', 'is_self') }
  to_item = ->(i) {  }
  Enumerator.new do |enum|
    loop do
      page  = get_page(after: after)
      items = page.dig('data', 'children')
      after = page.dig('data', 'after')
      items.reject(&is_self).map do |i|
        item = Reddit::Post.new(i.symbolize_names[:data]).to_item
        enum.yield(put_request: { item: item })
      end
      break if after.nil?
    end
  end
end

def main
  pages = get_items.each_slice(25).to_a
  items = pages.each_with_index do |page, i|
    $stderr.write("\rdynamodb:BatchWriteItem [#{i + 1}/#{pages.count}] ")
    DYNAMODB.batch_write_item(request_items: { 'brutalismbot-blue' => page })
  end
end

main
